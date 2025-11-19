"""
Motor control using CQRobot encoder logic
Based on: http://www.cqrobot.wiki/index.php/DC_Gearmotor_SKU:_CQR37D
"""

import machine
import time
import math
from machine import Pin, PWM

class CQRobotMotorController:
    def __init__(self):
        # Encoder pins (using CQRobot-style setup)
        self.encoder_a = Pin(8, Pin.IN, Pin.PULL_UP)  # GP8, Pico pin 9
        self.encoder_b = Pin(9, Pin.IN, Pin.PULL_UP)  # GP9, Pico pin 10

        # Motor control pins
        self.motor_ena = PWM(Pin(0))  # GP0, PWM for speed
        self.motor_in1 = Pin(1, Pin.OUT)  # GP1, Direction

        # Encoder configuration (from CQRobot specs)
        self.CPR = 64  # Counts per revolution (motor shaft)
        self.gear_ratio = 30.0  # Adjust based on your motor
        self.counts_per_output_rev = self.CPR * self.gear_ratio

        # Encoder state tracking (CQRobot style)
        self.encoder_count = 0
        self.encoder_a_last = self.encoder_a.value()
        self.direction_forward = True

        # Position tracking
        self.current_position = 0.0  # degrees

        # Velocity tracking
        self.last_time = time.ticks_us()
        self.last_count = 0
        self.current_velocity = 0.0  # RPM

        # Control variables
        self.target_position = 0.0  # degrees
        self.target_velocity = 0.0  # RPM
        self.control_mode = "velocity"

        # PID parameters
        self.kp = 2.0
        self.ki = 0.1
        self.kd = 0.05
        self.integral_error = 0.0
        self.last_position_error = 0.0

        # PWM configuration
        self.motor_ena.freq(1000)
        self.max_pwm = 65535
        self.min_pwm = 1000

        # Setup encoder interrupts (CQRobot style)
        self.encoder_a.irq(trigger=Pin.IRQ_RISING | Pin.IRQ_FALLING, handler=self.wheel_speed)

        print("CQRobot Motor controller initialized")
        print(f"Encoder CPR: {self.CPR}, Gear ratio: {self.gear_ratio}")
        print(f"Counts per output revolution: {self.counts_per_output_rev}")

    def wheel_speed(self, pin):
        """CQRobot-style encoder interrupt handler"""
        # Based on CQRobot sample code logic
        lstate = self.encoder_a.value()

        if (self.encoder_a_last == 0) and (lstate == 1):  # Rising edge on A
            val = self.encoder_b.value()
            if val == 0 and self.direction_forward:
                self.direction_forward = False  # Reverse
            elif val == 1 and not self.direction_forward:
                self.direction_forward = True   # Forward

        self.encoder_a_last = lstate

        # Update count based on direction
        if not self.direction_forward:
            self.encoder_count += 1
        else:
            self.encoder_count -= 1

    def get_position_degrees(self):
        """Get current position in degrees"""
        revolutions = self.encoder_count / self.counts_per_output_rev
        return revolutions * 360.0

    def get_velocity_rpm(self):
        """Calculate current velocity in RPM"""
        current_time = time.ticks_us()
        current_count = self.encoder_count

        dt = time.ticks_diff(current_time, self.last_time) / 1000000.0
        if dt > 0.01:
            count_diff = current_count - self.last_count
            rev_per_sec = count_diff / self.counts_per_output_rev
            self.current_velocity = rev_per_sec * 60.0

            self.last_time = current_time
            self.last_count = current_count

        return self.current_velocity

    def set_motor_speed(self, speed_rpm):
        """Set motor speed in RPM"""
        if abs(speed_rpm) < 0.1:
            self.motor_ena.duty_u16(0)
            return

        # Direction
        if speed_rpm > 0:
            self.motor_in1.value(1)
            self.direction_forward = True
        else:
            self.motor_in1.value(0)
            self.direction_forward = False

        # Speed scaling
        max_rpm = 150.0
        duty_percent = min(abs(speed_rpm) / max_rpm, 1.0)
        duty_value = int(self.min_pwm + (self.max_pwm - self.min_pwm) * duty_percent)
        self.motor_ena.duty_u16(duty_value)

    def position_control(self):
        """PID position control"""
        current_pos = self.get_position_degrees()
        error = self.target_position - current_pos

        self.integral_error += error * 0.01
        self.integral_error = max(-100, min(100, self.integral_error))

        derivative_error = (error - self.last_position_error) / 0.01
        self.last_position_error = error

        output = self.kp * error + self.ki * self.integral_error + self.kd * derivative_error

        max_velocity = 50.0
        velocity_command = max(-max_velocity, min(max_velocity, output))

        self.set_motor_speed(velocity_command)

    def velocity_control(self):
        """Direct velocity control"""
        self.set_motor_speed(self.target_velocity)

    def stop_motor(self):
        """Stop the motor"""
        self.motor_ena.duty_u16(0)
        self.target_velocity = 0.0

    def zero_position(self):
        """Zero the position counter"""
        self.encoder_count = 0
        self.integral_error = 0.0
        self.last_position_error = 0.0
        print("Position zeroed")

# Test functions
def test_encoder():
    """Test encoder feedback"""
    print("Testing CQRobot encoder...")

    motor = CQRobotMotorController()

    print(f"Initial count: {motor.encoder_count}")
    print(f"Initial position: {motor.get_position_degrees():.2f}°")

    # Wait a bit
    time.sleep(2)

    print(f"After 2s - count: {motor.encoder_count}")
    print(f"After 2s - position: {motor.get_position_degrees():.2f}°")

    motor.stop_motor()

def test_motor():
    """Test motor movement"""
    print("Testing CQRobot motor control...")

    motor = CQRobotMotorController()

    # Test speeds
    for speed in [10, 25, -10, -25]:
        print(f"Speed: {speed} RPM")
        motor.set_motor_speed(speed)
        time.sleep(3)
        motor.stop_motor()
        time.sleep(1)

def test_position():
    """Test position control"""
    print("Testing CQRobot position control...")

    motor = CQRobotMotorController()
    motor.zero_position()

    for target in [45, -45, 90, 0]:
        print(f"Moving to {target}°...")
        motor.target_position = target
        motor.control_mode = "position"

        start_time = time.time()
        while time.time() - start_time < 10:
            motor.position_control()
            current = motor.get_position_degrees()
            error = abs(current - target)
            print(".2f")
            if error < 3:
                break
            time.sleep(0.1)

        motor.stop_motor()
        time.sleep(1)

if __name__ == "__main__":
    test_encoder()
    test_motor()
    test_position()
