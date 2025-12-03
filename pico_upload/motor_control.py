"""
Raspberry Pi Pico Motor Control for CQR37D Geared Motor
Controls angular position and velocity through command line interface

Hardware Connections:
- Encoder A (white): GP8 (Pico pin 9)
- Encoder B (yellow): GP9 (Pico pin 10)
- Motor ENA: GP0 (Pico pin 1) - PWM for speed
- Motor IN1: GP1 (Pico pin 2) - Direction control

CQR37D Specifications:
- 64 counts per revolution (CPR) quadrature encoder
- Gear ratios available: 6.25:1 to 810:1 (assuming 30:1 for this example)
"""

import machine
import time
import math
from machine import Pin, PWM
import select
import sys

# Motor and Encoder Configuration
class MotorController:
    def __init__(self):
        # Encoder pins (interrupt capable)
        self.encoder_a = Pin(6, Pin.IN, Pin.PULL_UP)  # GP6, Pico pin 9 (white wire)
        self.encoder_b = Pin(7, Pin.IN, Pin.PULL_UP)  # GP7, Pico pin 10 (yellow wire)

        # Motor control pins for dual H-bridge controller
        self.motor_ena = PWM(Pin(0))  # GP0, Pico pin 1 - PWM for speed (ENA)
        self.motor_in1 = Pin(2, Pin.OUT)  # GP2, Pico pin 4 - Direction control (IN1)
        self.motor_in2 = Pin(1, Pin.OUT)  # GP1, Pico pin 2 - Direction control (IN2)

        # Encoder configuration
        self.CPR = 64  # Counts per revolution (motor shaft)
        self.gear_ratio = 30.0  # Example gear ratio (adjust based on your motor)
        self.counts_per_output_rev = self.CPR * self.gear_ratio

        # Position tracking
        self.encoder_count = 0
        self.last_a_state = self.encoder_a.value()
        self.last_b_state = self.encoder_b.value()

        # Velocity tracking
        self.last_time = time.ticks_us()
        self.last_count = 0
        self.current_velocity = 0.0  # RPM

        # Control variables
        self.target_position = 0.0  # degrees
        self.target_velocity = 0.0  # RPM
        self.current_position = 0.0  # degrees
        self.control_mode = "velocity"  # "position" or "velocity"
        self.last_motion_sign = 0  # Tracks last observed rotation direction

        # PID parameters for position control
        self.kp = 2.0
        self.ki = 0.1
        self.kd = 0.05
        self.integral_error = 0.0
        self.last_position_error = 0.0

        # Virtual wall (encoder-backed hold) state
        self.wall_engaged = False
        self.wall_contact_position_deg = 0.0
        self.wall_direction = 1  # +1/-1 penetration direction
        self.wall_force_newtons = 0.0
        self.wall_kp_min = 1.0
        self.wall_kp_max = 8.0
        self.wall_kd_min = 0.02
        self.wall_kd_max = 0.12
        self.wall_release_tol_deg = 0.25  # deadband around wall surface
        self.last_wall_error = 0.0
        self.last_wall_time_ms = time.ticks_ms()
        self.prev_position_deg = 0.0

        # Haptic feedback
        self.haptic_brake_percent = 0.0  # 0.0 to 1.0 (0% to 100% braking)

        # PWM configuration
        self.motor_ena.freq(1000)  # 1kHz PWM frequency
        self.max_pwm = 65535
        self.min_pwm = 1000  # Minimum PWM to overcome motor deadband
        # Limit the braking duty cycle to avoid overheating while keeping it proportional
        self.max_brake_scale = 0.6

        # Setup encoder interrupts
        self.encoder_a.irq(trigger=Pin.IRQ_RISING | Pin.IRQ_FALLING, handler=self.encoder_callback)
        self.encoder_b.irq(trigger=Pin.IRQ_RISING | Pin.IRQ_FALLING, handler=self.encoder_callback)

        print("Motor controller initialized")
        print(f"Encoder CPR: {self.CPR}, Gear ratio: {self.gear_ratio}")
        print(f"Counts per output revolution: {self.counts_per_output_rev}")

    def encoder_callback(self, pin):
        """Interrupt handler for encoder signals"""
        a_state = self.encoder_a.value()
        b_state = self.encoder_b.value()

        # Quadrature decoding
        if a_state != self.last_a_state:
            if a_state == b_state:
                self.encoder_count += 1
            else:
                self.encoder_count -= 1

        self.last_a_state = a_state
        self.last_b_state = b_state

    def get_position_degrees(self):
        """Get current position in degrees"""
        revolutions = self.encoder_count / self.counts_per_output_rev
        return revolutions * 360.0

    def get_velocity_rpm(self):
        """Calculate current velocity in RPM"""
        current_time = time.ticks_us()
        current_count = self.encoder_count

        dt = time.ticks_diff(current_time, self.last_time) / 1000000.0  # seconds
        if dt > 0.01:  # Update every 10ms minimum
            count_diff = current_count - self.last_count
            rev_per_sec = count_diff / self.counts_per_output_rev
            self.current_velocity = rev_per_sec * 60.0
            if count_diff > 0:
                self.last_motion_sign = 1
            elif count_diff < 0:
                self.last_motion_sign = -1

            self.last_time = current_time
            self.last_count = current_count

        return self.current_velocity

    def set_motor_speed(self, speed_rpm):
        """Set motor speed in RPM (positive = one direction, negative = other)"""
        # Update target velocity tracker so haptic logic knows the current command
        self.target_velocity = speed_rpm

        # If haptics are active, braking takes priority over driving to create resistance
        if self._apply_haptic_brake():
            return

        if abs(speed_rpm) < 0.1:  # Stop threshold
            self.motor_ena.duty_u16(0)
            self.motor_in1.value(0)
            self.motor_in2.value(0)
            self.last_motion_sign = 0
            return

        # Direction control for dual H-bridge
        # Forward: IN1=HIGH, IN2=LOW
        # Reverse: IN1=LOW, IN2=HIGH
        if speed_rpm > 0:
            self.motor_in1.value(1)
            self.motor_in2.value(0)
            self.last_motion_sign = 1
        else:
            self.motor_in1.value(0)
            self.motor_in2.value(1)
            self.last_motion_sign = -1

        # Speed (scale RPM to PWM duty cycle)
        # Assuming max RPM is around 100-200 for geared motor, adjust as needed
        max_rpm = 150.0
        duty_percent = min(abs(speed_rpm) / max_rpm, 1.0)

        duty_value = int(self.min_pwm + (self.max_pwm - self.min_pwm) * duty_percent)
        self.motor_ena.duty_u16(duty_value)

    def _apply_haptic_brake(self):
        """Apply electromagnetic braking using Hapkit-style torque control.
        Based on Arduino Hapkit algorithm for proper force rendering.

        Returns:
            bool: True if braking was applied, False otherwise.
        """
        if self.haptic_brake_percent <= 0:
            return False

        # Short the motor leads to create resistive torque (electromagnetic braking)
        self.motor_in1.value(1)
        self.motor_in2.value(1)

        # Hapkit-style torque control
        brake_percent = min(self.haptic_brake_percent, 1.0)

        # Calculate torque-to-duty conversion using Hapkit formula
        # duty = sqrt(abs(Tp)/0.03) where Tp is motor pulley torque
        # Since brake_percent represents normalized torque, we adapt this
        torque_factor = 0.03  # Hapkit constant for duty cycle calculation
        duty_float = math.sqrt(brake_percent / torque_factor) if brake_percent > 0 else 0

        # Clamp duty cycle and convert to PWM value
        duty_float = min(duty_float, 1.0)
        duty_value = int(duty_float * (self.max_pwm - self.min_pwm) + self.min_pwm)

        # Apply PWM duty cycle for controlled braking torque
        self.motor_ena.duty_u16(duty_value)

        print(f"🧱 Hapkit virtual wall: brake_percent={brake_percent:.3f}, duty_float={duty_float:.3f}, PWM={duty_value}")
        return True

    def position_control(self):
        """PID position control"""
        current_pos = self.get_position_degrees()
        error = self.target_position - current_pos

        # PID calculations
        self.integral_error += error * 0.01  # Assuming 100Hz control loop
        self.integral_error = max(-100, min(100, self.integral_error))  # Anti-windup

        derivative_error = (error - self.last_position_error) / 0.01
        self.last_position_error = error

        output = self.kp * error + self.ki * self.integral_error + self.kd * derivative_error

        # Convert position error to velocity command
        max_velocity = 50.0  # Max RPM for position control
        velocity_command = max(-max_velocity, min(max_velocity, output))

        self.set_motor_speed(velocity_command)

    def velocity_control(self):
        """Direct velocity control"""
        self.set_motor_speed(self.target_velocity)

    def stop_motor(self):
        """Stop the motor"""
        self.motor_ena.duty_u16(0)
        self.motor_in1.value(0)
        self.motor_in2.value(0)
        self.target_velocity = 0.0
        self.last_motion_sign = 0
        self.wall_engaged = False
        self.control_mode = "velocity"

    def hold_position_here(self):
        """Capture current encoder position and hold it with PID."""
        self.target_position = self.get_position_degrees()
        self.integral_error = 0.0
        self.last_position_error = 0.0
        self.control_mode = "position"
        print(f"Holding position at {self.target_position:.2f} degrees")

    def zero_position(self):
        """Zero the position counter"""
        self.encoder_count = 0
        self.integral_error = 0.0
        self.last_position_error = 0.0
        print("Position zeroed")

    def set_haptic_feedback(self, brake_percent):
        """Set haptic feedback braking level (0.0 to 1.0)

        Args:
            brake_percent: Braking level from 0.0 (no braking) to 1.0 (full braking)
        """
        # Invert brake_percent: 0 (no resistance) → 1.0, 100 (max resistance) → 0
        self.haptic_brake_percent = max(0.0, min(1.0, 1.0 - brake_percent))

    def set_force_feedback(self, force_newtons, motor_rpm):
        """Set active force feedback using motor control (virtual spring wall)

        Args:
            force_newtons: Required force in Newtons (can be negative)
            motor_rpm: Motor speed in RPM to achieve the force
        """
        # Store force command for feedback
        self.force_command = force_newtons
        self.target_velocity = motor_rpm

        # For virtual spring wall, we want active motor control, not just braking
        # Drive the motor actively to create the required force/torque

        if abs(motor_rpm) < 0.1:
            # No movement required - hold position with minimal torque
            self.motor_ena.duty_u16(0)
            self.motor_in1.value(0)
            self.motor_in2.value(0)
        else:
            # Active motor driving to create force
            if motor_rpm > 0:
                self.motor_in1.value(1)
                self.motor_in2.value(0)
            else:
                self.motor_in1.value(0)
                self.motor_in2.value(1)

            # Scale RPM to PWM duty cycle
            max_rpm = 150.0
            duty_percent = min(abs(motor_rpm) / max_rpm, 1.0)
            duty_value = int(self.min_pwm + (self.max_pwm - self.min_pwm) * duty_percent)
            self.motor_ena.duty_u16(duty_value)

        print(f"🧱 Active force feedback: {force_newtons:.2f}N, Motor: {motor_rpm:.1f} RPM")

    def set_raw_driver(self, ena_duty, in1, in2):
        """Manual control of motor driver pins for debugging"""
        self.motor_ena.duty_u16(int(ena_duty))
        self.motor_in1.value(int(in1))
        self.motor_in2.value(int(in2))
        self.control_mode = "raw"
        print(f"Raw driver set: ENA={ena_duty}, IN1={in1}, IN2={in2}")

    def set_spring_wall(self, force_newtons, wall_flag=1):
        """Encoder-backed virtual wall: capture surface and hold position.

        Args:
            force_newtons: Penetration-based force request (0-50N typical)
            wall_flag: Non-zero engages the wall. If a legacy RPM is passed in,
                       its sign is used as a direction hint.
        """
        # Clamp force and store for debugging/telemetry
        self.wall_force_newtons = max(0.0, min(force_newtons, 50.0))
        self.force_command = self.wall_force_newtons

        # Legacy compatibility: if wall_flag looks like an RPM, use its sign as a hint
        direction_hint = None
        if abs(wall_flag) > 1.0:
            direction_hint = -1 if wall_flag < 0 else 1
        active = self.wall_force_newtons > 0.0 and wall_flag != 0

        if not active:
            # Release the wall and let the handle spin freely
            self.wall_engaged = False
            self.haptic_brake_percent = 0.0
            self.control_mode = "velocity"
            self.motor_ena.duty_u16(0)
            self.motor_in1.value(0)
            self.motor_in2.value(0)
            return

        if not self.wall_engaged:
            # First contact: capture the wall surface at the current encoder angle
            self.wall_contact_position_deg = self.get_position_degrees()
            self.prev_position_deg = self.wall_contact_position_deg

            velocity_hint = self.get_velocity_rpm()
            if abs(velocity_hint) < 0.5:
                velocity_hint = self.last_motion_sign

            if direction_hint is not None:
                self.wall_direction = direction_hint
            else:
                self.wall_direction = 1 if velocity_hint >= 0 else -1

            self.last_wall_error = 0.0
            self.last_wall_time_ms = time.ticks_ms()
            print(f"🧱 Virtual wall engaged @ {self.wall_contact_position_deg:.2f}°, dir={self.wall_direction:+d}, force={self.wall_force_newtons:.1f}N")
        else:
            # Allow direction hint updates while engaged (for compatibility)
            if direction_hint is not None:
                self.wall_direction = direction_hint

        self.wall_engaged = True
        self.control_mode = "virtual_wall"
        self.haptic_brake_percent = 0.0

    def virtual_wall_control(self):
        """POSITION-BASED virtual wall - holds position with reasonable PID gains."""
        if not self.wall_engaged:
            return

        # Get current encoder position
        current_pos = self.get_position_degrees()

        # Calculate penetration depth (how far past the wall surface)
        penetration_deg = (current_pos - self.wall_contact_position_deg) * self.wall_direction

        # If we're at or outside the wall surface (user backed out), free the motor
        if penetration_deg < self.wall_release_tol_deg:
            self.motor_ena.duty_u16(0)
            self.motor_in1.value(0)
            self.motor_in2.value(0)
            return

        # USER IS PENETRATING THE WALL - USE SPRING FORCE MODEL (Hapkit Style)
        # Implements F = -k * x logic from virtual_effects_template.ino
        
        # 1. Calculate penetration distance in meters
        # Assume a handle radius (rh) to map rotation to linear distance
        rh = 0.05  # [m] Effective handle radius (5 cm as per user)
        
        # penetration_deg is how far "inside" the wall we are
        # Convert to radians then meters
        x_penetration = (penetration_deg * math.pi / 180.0) * rh
        
        # 2. Calculate Spring Force (Hooke's Law)
        # k = Stiffness [N/m]
        # Use a fixed stiffness similar to the template (200 N/m) 
        # or scale with the requested force if desired. 
        # The template uses k=200.0.
        k = 200.0 
        
        # Force is proportional to penetration
        force = k * x_penetration  # [N] Magnitude of restoring force

        # --- VIBRATION EFFECT ---
        # Add sinusoidal vibration scaled by force to simulate cutting texture
        # Frequency: 10Hz (User requested)
        # Amplitude: 100% of current wall force (User requested 5x stronger)
        vib_freq = 10.0
        vib_amp_scale = 1.0
        t_sec = time.ticks_ms() / 1000.0
        vibration = force * vib_amp_scale * math.sin(2 * math.pi * vib_freq * t_sec)
        force += vibration
        force = max(0.0, force) # Clamp to ensure we don't pull into wall
        # ------------------------
        
        # 3. Calculate Motor Torque
        # Torque at handle = Force * radius
        # Torque at motor = Torque at handle / Gear Ratio
        torque_handle = force * rh
        torque_motor = torque_handle / self.gear_ratio
        
        # 4. Convert Torque to Duty Cycle (Hapkit Non-linear Mapping)
        # Template: duty = sqrt(abs(Tp)/0.03)
        # This compensates for motor/driver non-linearities
        if torque_motor > 0:
            duty_cycle = math.sqrt(torque_motor / 0.03)
        else:
            duty_cycle = 0.0
            
        # Clamp duty cycle
        duty_cycle = min(duty_cycle, 1.0)
        
        # 5. Apply to Motor
        # Determine direction: Push OUT of the wall
        # If wall_direction is 1 (positive is in), we push negative (0)
        # If wall_direction is -1 (negative is in), we push positive (1)
        
        # Logic check:
        # If wall_dir = 1, we are at pos > wall. We want to move negative.
        # Motor direction for negative speed: IN1=0, IN2=1 (from set_motor_speed)
        # If wall_dir = -1, we are at pos < wall. We want to move positive.
        # Motor direction for positive speed: IN1=1, IN2=0
        
        push_positive = (self.wall_direction == -1)
        
        if push_positive:
            self.motor_in1.value(1)
            self.motor_in2.value(0)
        else:
            self.motor_in1.value(0)
            self.motor_in2.value(1)
            
        # Convert duty to PWM
        duty_value = int(self.min_pwm + (self.max_pwm - self.min_pwm) * duty_cycle)
        self.motor_ena.duty_u16(duty_value)

        # print(f"🧱 WALL: pen={x_penetration*1000:.1f}mm, F={force:.1f}N, T_m={torque_motor:.3f}Nm, D={duty_cycle:.2f}")

    def set_pid_gains(self, kp, ki, kd):
        """Set PID gains for position control"""
        self.kp = kp
        self.ki = ki
        self.kd = kd
        print(f"PID gains set: Kp={kp}, Ki={ki}, Kd={kd}")

def print_help():
    """Print available commands"""
    print("\nAvailable Commands:")
    print("pos <degrees>     - Set target position (degrees)")
    print("vel <rpm>         - Set target velocity (RPM)")
    print("stop              - Stop motor")
    print("zero              - Zero position counter")
    print("pid <kp> <ki> <kd> - Set PID gains")
    print("hold              - Hold the current encoder position")
    print("spring_wall <forceN> [active|rpm_hint] - Engage virtual wall at current position")
    print("status            - Show current status")
    print("help              - Show this help")
    print("quit              - Exit program")

def main():
    print("Raspberry Pi Pico CQR37D Motor Controller")
    print("==========================================")

    # Initialize motor controller
    motor = MotorController()

    # Control loop timing
    last_control_time = time.ticks_ms()

    print("\nType 'help' for available commands")
    print("Current mode: velocity control")

    while True:
        # Check for serial input
        if select.select([sys.stdin], [], [], 0)[0]:
            try:
                command = input().strip().lower()
                parts = command.split()

                if not parts:
                    continue

                cmd = parts[0]

                if cmd == "help":
                    print_help()

                elif cmd == "pos" and len(parts) == 2:
                    try:
                        target_pos = float(parts[1])
                        motor.target_position = target_pos
                        motor.control_mode = "position"
                        print(f"Position control: target = {target_pos} degrees")
                    except ValueError:
                        print("Invalid position value")

                elif cmd == "vel" and len(parts) == 2:
                    try:
                        target_vel = float(parts[1])
                        motor.target_velocity = target_vel
                        motor.control_mode = "velocity"
                        print(f"Velocity control: target = {target_vel} RPM")
                    except ValueError:
                        print("Invalid velocity value")

                elif cmd == "hold":
                    motor.hold_position_here()

                elif cmd == "spring_wall" and len(parts) >= 2:
                    try:
                        force_val = float(parts[1])
                        wall_flag = float(parts[2]) if len(parts) >= 3 else 1.0
                        motor.set_spring_wall(force_val, wall_flag)
                        state = "engaged" if force_val > 0 and wall_flag != 0 else "released"
                        print(f"Virtual wall {state}: force={force_val:.2f}N, flag={wall_flag}")
                    except ValueError:
                        print("Invalid spring_wall values")

                elif cmd == "stop":
                    motor.stop_motor()
                    print("Motor stopped")

                elif cmd == "zero":
                    motor.zero_position()

                elif cmd == "pid" and len(parts) == 4:
                    try:
                        kp = float(parts[1])
                        ki = float(parts[2])
                        kd = float(parts[3])
                        motor.set_pid_gains(kp, ki, kd)
                    except ValueError:
                        print("Invalid PID values")

                elif cmd == "status":
                    current_pos = motor.get_position_degrees()
                    current_vel = motor.get_velocity_rpm()
                    status_line = f"Position: {current_pos:.2f} degrees, Velocity: {current_vel:.2f} RPM, Mode: {motor.control_mode}"
                    if motor.wall_engaged:
                        status_line += f", Wall @ {motor.wall_contact_position_deg:.2f}°, dir={motor.wall_direction:+d}, force={motor.wall_force_newtons:.1f}N"
                    print(status_line)

                elif cmd == "quit":
                    motor.stop_motor()
                    print("Exiting...")
                    break

                else:
                    print("Unknown command. Type 'help' for available commands")

            except Exception as e:
                print(f"Error processing command: {e}")

        # Control loop (100Hz)
        current_time = time.ticks_ms()
        if time.ticks_diff(current_time, last_control_time) >= 10:  # 10ms = 100Hz
            if motor.control_mode == "position":
                motor.position_control()
            elif motor.control_mode == "velocity":
                motor.velocity_control()
            elif motor.control_mode == "virtual_wall":
                motor.virtual_wall_control()

            last_control_time = current_time

        # Small delay to prevent busy waiting
        time.sleep(0.001)

if __name__ == "__main__":
    main()
