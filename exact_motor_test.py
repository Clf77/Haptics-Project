"""
Test motor using EXACT same logic as working velocity control
"""

import machine
import time
from machine import Pin, PWM

class TestMotorController:
    """Simplified motor controller using exact same logic as working version"""

    def __init__(self):
        # Motor control pins
        self.motor_ena = PWM(Pin(0))  # GP0, PWM for speed
        self.motor_in1 = Pin(1, Pin.OUT)  # GP1, Direction

        # PWM configuration (exact same as motor_control.py)
        self.motor_ena.freq(1000)  # 1kHz PWM frequency
        self.max_pwm = 65535
        self.min_pwm = 1000  # Minimum PWM to overcome motor deadband

    def set_motor_speed(self, speed_rpm):
        """EXACT same logic as working motor_control.py"""
        if abs(speed_rpm) < 0.1:  # Stop threshold
            self.motor_ena.duty_u16(0)
            return

        # Direction (exact same logic)
        if speed_rpm > 0:
            self.motor_in1.value(1)
        else:
            self.motor_in1.value(0)

        # Speed (exact same scaling as working version)
        # Assuming max RPM is around 100-200 for geared motor, adjust as needed
        max_rpm = 150.0
        duty_percent = min(abs(speed_rpm) / max_rpm, 1.0)
        duty_value = int(self.min_pwm + (self.max_pwm - self.min_pwm) * duty_percent)
        self.motor_ena.duty_u16(duty_value)

        print(f"Set speed {speed_rpm} RPM → direction {self.motor_in1.value()} → duty {duty_value}")

    def stop_motor(self):
        """Stop the motor"""
        self.motor_ena.duty_u16(0)
        print("Motor stopped")

def test_working_logic():
    """Test using EXACT same logic as the working velocity control"""
    print("Testing with EXACT working motor control logic")
    print("==============================================")

    motor = TestMotorController()

    print("Testing different speeds that worked before...")

    # Test speeds that worked in velocity control
    test_speeds = [10, 25, 50, -10, -25, -50]

    for speed in test_speeds:
        print(f"\nTesting {speed} RPM for 3 seconds...")
        motor.set_motor_speed(speed)
        time.sleep(3)
        motor.stop_motor()
        time.sleep(1)

    print("\nAll tests complete - did the motor move this time?")

def test_manual_control():
    """Manual control to test different scenarios"""
    print("\nManual Motor Control Test")
    print("=========================")

    motor = TestMotorController()

    print("Commands:")
    print("f <speed> - forward at speed RPM")
    print("r <speed> - reverse at speed RPM")
    print("s - stop")
    print("q - quit")
    print()

    while True:
        try:
            cmd = input("Command: ").strip().lower()
            if not cmd:
                continue

            parts = cmd.split()
            action = parts[0]

            if action == 'q':
                break
            elif action == 's':
                motor.stop_motor()
            elif action in ['f', 'r'] and len(parts) == 2:
                try:
                    speed = float(parts[1])
                    if action == 'r':
                        speed = -speed
                    motor.set_motor_speed(speed)
                except ValueError:
                    print("Invalid speed")
            else:
                print("Invalid command")

        except KeyboardInterrupt:
            break

    motor.stop_motor()

if __name__ == "__main__":
    test_working_logic()
    test_manual_control()
