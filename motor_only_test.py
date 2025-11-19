"""
Test motor movement without encoder complications
"""

import machine
import time
from machine import Pin, PWM

def test_motor_basic():
    """Basic motor test - just check if motor moves"""
    print("Basic Motor Movement Test")
    print("========================")

    # Set up motor pins
    motor_ena = PWM(Pin(0))  # GP0, PWM for speed
    motor_in1 = Pin(1, Pin.OUT)  # GP1, Direction

    motor_ena.freq(1000)

    print("Motor pins initialized")
    print(f"PWM frequency: {motor_ena.freq()} Hz")
    print(f"Direction pin: {motor_in1.value()}")

    # Test sequence
    speeds = [10000, 20000, 30000, 40000, 50000]

    print("\nTesting FORWARD direction...")
    motor_in1.value(1)  # Forward

    for speed in speeds:
        print(f"Setting speed to {speed} (forward)")
        motor_ena.duty_u16(speed)
        time.sleep(2)  # Run for 2 seconds
        print(f"Current duty: {motor_ena.duty_u16()}")

    print("Stopping motor...")
    motor_ena.duty_u16(0)
    time.sleep(1)

    print("\nTesting REVERSE direction...")
    motor_in1.value(0)  # Reverse

    for speed in speeds:
        print(f"Setting speed to {speed} (reverse)")
        motor_ena.duty_u16(speed)
        time.sleep(2)  # Run for 2 seconds
        print(f"Current duty: {motor_ena.duty_u16()}")

    print("Stopping motor...")
    motor_ena.duty_u16(0)

    print("\nTest complete - did you see the motor move?")

def test_motor_driver_signals():
    """Test just the driver signals without timing"""
    print("\nMotor Driver Signal Test")
    print("========================")

    motor_ena = PWM(Pin(0))
    motor_in1 = Pin(1, Pin.OUT)
    motor_ena.freq(1000)

    print("Testing driver control signals...")

    # Manual control
    print("Forward full speed - press Enter when ready to continue")
    motor_in1.value(1)
    motor_ena.duty_u16(65535)  # Full speed
    input()

    print("Reverse full speed - press Enter when ready to continue")
    motor_in1.value(0)
    motor_ena.duty_u16(65535)  # Full speed
    input()

    print("Stopping motor")
    motor_ena.duty_u16(0)

if __name__ == "__main__":
    test_motor_basic()
    test_motor_driver_signals()
