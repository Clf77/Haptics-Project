"""
Diagnostic script for motor control hardware
"""

import machine
import time
from machine import Pin, PWM

def test_pins():
    """Test basic pin functionality"""
    print("Testing pin functionality...")

    # Test encoder pins
    enc_a = Pin(8, Pin.IN, Pin.PULL_UP)
    enc_b = Pin(9, Pin.IN, Pin.PULL_UP)

    print(f"Encoder A (GP8): {enc_a.value()}")
    print(f"Encoder B (GP9): {enc_b.value()}")

    # Test motor control pins
    motor_ena = PWM(Pin(0))
    motor_in1 = Pin(1, Pin.OUT)

    print("Motor control pins initialized successfully")

def test_motor_driver():
    """Test motor driver by pulsing outputs"""
    print("\nTesting motor driver...")

    motor_ena = PWM(Pin(0))
    motor_in1 = Pin(1, Pin.OUT)

    motor_ena.freq(1000)

    print("Setting motor to forward, 50% speed for 2 seconds...")
    motor_in1.value(1)
    motor_ena.duty_u16(32767)  # 50% duty cycle
    time.sleep(2)

    print("Stopping motor...")
    motor_ena.duty_u16(0)
    time.sleep(1)

    print("Setting motor to reverse, 50% speed for 2 seconds...")
    motor_in1.value(0)
    motor_ena.duty_u16(32767)  # 50% duty cycle
    time.sleep(2)

    print("Stopping motor...")
    motor_ena.duty_u16(0)

def test_encoder_raw():
    """Test raw encoder values"""
    print("\nTesting encoder (manual rotation needed)...")

    enc_a = Pin(8, Pin.IN, Pin.PULL_UP)
    enc_b = Pin(9, Pin.IN, Pin.PULL_UP)

    start_a = enc_a.value()
    start_b = enc_b.value()

    print(f"Initial: A={start_a}, B={start_b}")

    print("Rotate motor 1 full turn, then press Enter...")
    input()  # Wait for user input

    end_a = enc_a.value()
    end_b = enc_b.value()

    print(f"Final: A={end_a}, B={end_b}")

    if start_a != end_a or start_b != end_b:
        print("✓ Encoder signals are changing - encoder is working!")
    else:
        print("✗ Encoder signals not changing - check connections!")

def main():
    print("Motor Control Hardware Diagnostics")
    print("==================================")

    test_pins()
    test_motor_driver()
    test_encoder_raw()

    print("\nDiagnostics complete!")

if __name__ == "__main__":
    main()
