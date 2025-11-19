"""
Simple motor test - just try to make the motor move
"""

import machine
import time
from machine import Pin, PWM

def test_motor_movement():
    """Test if motor moves at all"""
    print("Testing basic motor movement...")

    # Motor control pins
    motor_ena = PWM(Pin(0))  # GP0, PWM for speed
    motor_in1 = Pin(1, Pin.OUT)  # GP1, Direction

    motor_ena.freq(1000)

    print("Direction pin (IN1):", motor_in1.value())
    print("PWM duty cycle:", motor_ena.duty_u16())

    # Test forward
    print("\nTesting FORWARD direction...")
    motor_in1.value(1)  # Forward
    for duty in [10000, 20000, 30000, 40000, 50000, 65535]:
        print(f"Setting PWM duty to {duty} (forward)")
        motor_ena.duty_u16(duty)
        time.sleep(3)
        print("PWM duty:", motor_ena.duty_u16())

    motor_ena.duty_u16(0)
    time.sleep(1)

    # Test reverse
    print("\nTesting REVERSE direction...")
    motor_in1.value(0)  # Reverse
    for duty in [10000, 20000, 30000, 40000, 50000, 65535]:
        print(f"Setting PWM duty to {duty} (reverse)")
        motor_ena.duty_u16(duty)
        time.sleep(3)
        print("PWM duty:", motor_ena.duty_u16())

    # Stop
    motor_ena.duty_u16(0)
    print("\nMotor test complete - did you see any movement?")

if __name__ == "__main__":
    test_motor_movement()
