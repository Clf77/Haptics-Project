"""
Comprehensive encoder and position control debugging
"""

import machine
import time
from machine import Pin, PWM

def test_raw_encoder_pins():
    """Test raw encoder pin signals without interrupts"""
    print("Raw Encoder Pin Test")
    print("====================")

    enc_a = Pin(8, Pin.IN, Pin.PULL_UP)
    enc_b = Pin(9, Pin.IN, Pin.PULL_UP)

    print("Testing encoder pins for 10 seconds...")
    print("A | B | Time")

    start_time = time.time()
    last_a = enc_a.value()
    last_b = enc_b.value()
    changes = 0

    while time.time() - start_time < 10:
        a_val = enc_a.value()
        b_val = enc_b.value()

        if a_val != last_a or b_val != last_b:
            timestamp = time.time() - start_time
            print(f"{a_val} | {b_val} | {timestamp:.2f}s")
            changes += 1
            last_a = a_val
            last_b = b_val

        time.sleep(0.001)  # 1ms polling

    print(f"Total signal changes: {changes}")
    if changes > 10:
        print("✓ Encoder signals detected - wiring looks good!")
    elif changes > 0:
        print("⚠ Some encoder signals detected - check connections")
    else:
        print("✗ No encoder signals detected - check wiring!")

def test_motor_encoder_feedback():
    """Test encoder feedback while motor is running"""
    print("\nMotor + Encoder Feedback Test")
    print("=============================")

    # Motor pins
    motor_ena = PWM(Pin(0))
    motor_in1 = Pin(1, Pin.OUT)
    motor_ena.freq(1000)

    # Encoder pins
    enc_a = Pin(8, Pin.IN, Pin.PULL_UP)
    enc_b = Pin(9, Pin.IN, Pin.PULL_UP)

    encoder_count = 0
    last_a = enc_a.value()
    last_b = enc_b.value()

    def simple_encoder_callback(pin):
        nonlocal encoder_count, last_a, last_b
        a = enc_a.value()
        b = enc_b.value()

        if a != last_a:
            if a == b:
                encoder_count += 1
            else:
                encoder_count -= 1

        last_a = a
        last_b = b

    # Set up interrupts
    enc_a.irq(trigger=Pin.IRQ_RISING | Pin.IRQ_FALLING, handler=simple_encoder_callback)
    enc_b.irq(trigger=Pin.IRQ_RISING | Pin.IRQ_FALLING, handler=simple_encoder_callback)

    print("Starting motor at low speed...")

    # Forward direction
    motor_in1.value(1)
    motor_ena.duty_u16(15000)  # Low speed

    start_count = encoder_count
    start_time = time.time()

    while time.time() - start_time < 5:
        current_count = encoder_count
        elapsed = time.time() - start_time
        print(f"Time: {elapsed:.1f}s, Count: {current_count}, Change: {current_count - start_count}")
        time.sleep(0.5)

    motor_ena.duty_u16(0)
    final_count = encoder_count
    count_change = final_count - start_count

    print(f"Final count change: {count_change}")

    if count_change > 50:
        print("✓ Good encoder feedback!")
    elif count_change > 10:
        print("⚠ Weak encoder feedback")
    else:
        print("✗ Poor encoder feedback - check wiring")

    # Clean up interrupts
    enc_a.irq(None)
    enc_b.irq(None)

def test_position_calculation():
    """Test position calculation with manual encoder simulation"""
    print("\nPosition Calculation Test")
    print("=========================")

    # Simulate encoder counts and test position calculation
    cpr = 64
    gear_ratio = 30.0
    counts_per_rev = cpr * gear_ratio

    print(f"CPR: {cpr}, Gear ratio: {gear_ratio}, Counts/rev: {counts_per_rev}")

    # Test various encoder counts
    test_counts = [0, 192, 960, 1920, -192, -960]

    for count in test_counts:
        revolutions = count / counts_per_rev
        position_deg = revolutions * 360.0
        print(f"Count: {count:4d} → Revolutions: {revolutions:.3f} → Position: {position_deg:6.1f}°")

def test_pid_response():
    """Test PID controller response"""
    print("\nPID Response Test")
    print("=================")

    from motor_control import MotorController

    motor = MotorController()

    print("Testing PID step response...")

    # Start at position 0
    motor.zero_position()
    motor.target_position = 45.0
    motor.control_mode = "position"

    print("Moving to 45° with PID control...")
    print("Time(s) | Position(°) | Error(°) | PWM Duty")

    start_time = time.time()
    positions = []
    errors = []

    while time.time() - start_time < 8:
        motor.position_control()
        current_pos = motor.get_position_degrees()
        error = motor.target_position - current_pos
        pwm_duty = motor.motor_ena.duty_u16()

        positions.append(current_pos)
        errors.append(error)

        # Print every 0.5 seconds
        elapsed = time.time() - start_time
        if int(elapsed * 2) % 2 == 0 and len(positions) % 25 == 0:
            print(".1f")

        time.sleep(0.01)

    final_pos = motor.get_position_degrees()
    final_error = abs(final_pos - 45.0)

    print(".1f")

    if final_error < 5.0:
        print("✓ PID control working!")
    else:
        print("⚠ PID control needs tuning - check encoder feedback")

    motor.stop_motor()

    # Analyze response
    if positions:
        max_pos = max(positions)
        min_pos = min(positions)
        overshoot = max_pos - 45.0 if max_pos > 45.0 else 0
        print(".1f")
        print(".1f")

def main():
    print("Comprehensive Encoder & Position Control Debug")
    print("==============================================")

    test_raw_encoder_pins()
    test_motor_encoder_feedback()
    test_position_calculation()
    test_pid_response()

    print("\nDebug complete!")

if __name__ == "__main__":
    main()
