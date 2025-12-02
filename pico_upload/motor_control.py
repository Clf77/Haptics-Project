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
        self.motor_in1 = Pin(1, Pin.OUT)  # GP1, Pico pin 2 - Direction control (IN1)
        self.motor_in2 = Pin(2, Pin.OUT)  # GP2, Pico pin 4 - Direction control (IN2)

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

        # PID parameters for position control
        self.kp = 2.0
        self.ki = 0.1
        self.kd = 0.05
        self.integral_error = 0.0
        self.last_position_error = 0.0

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
            return

        # Direction control for dual H-bridge
        # Forward: IN1=HIGH, IN2=LOW
        # Reverse: IN1=LOW, IN2=HIGH
        if speed_rpm > 0:
            self.motor_in1.value(1)
            self.motor_in2.value(0)
        else:
            self.motor_in1.value(0)
            self.motor_in2.value(1)

        # Speed (scale RPM to PWM duty cycle)
        # Assuming max RPM is around 100-200 for geared motor, adjust as needed
        max_rpm = 150.0
        duty_percent = min(abs(speed_rpm) / max_rpm, 1.0)

        duty_value = int(self.min_pwm + (self.max_pwm - self.min_pwm) * duty_percent)
        self.motor_ena.duty_u16(duty_value)

    def _apply_haptic_brake(self):
        """Apply electromagnetic braking proportional to haptic_brake_percent.

        Returns:
            bool: True if braking was applied, False otherwise.
        """
        if self.haptic_brake_percent <= 0:
            return False

        # Short the motor leads to create resistive torque
        self.motor_in1.value(1)
        self.motor_in2.value(1)

        # Higher brake percent -> higher duty, capped for safety
        brake_strength = min(self.haptic_brake_percent, 1.0) * self.max_brake_scale
        brake_duty = int(self.min_pwm + (self.max_pwm - self.min_pwm) * brake_strength)
        self.motor_ena.duty_u16(brake_duty)
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
        self.haptic_brake_percent = max(0.0, min(1.0, brake_percent))

        # Apply braking immediately
        if self._apply_haptic_brake():
            return

        # No braking - coast freely
        self.motor_in1.value(0)
        self.motor_in2.value(0)
        self.motor_ena.duty_u16(0)

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
                    print(".2f")
                    print(f"Control mode: {motor.control_mode}")
                    if motor.control_mode == "position":
                        print(".2f")
                    else:
                        print(".2f")

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

            last_control_time = current_time

        # Small delay to prevent busy waiting
        time.sleep(0.001)

if __name__ == "__main__":
    main()
