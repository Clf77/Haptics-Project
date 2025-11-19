"""
Simple position control test - avoids memory issues
"""

import time
from motor_control import MotorController

def simple_position_test():
    """Simple position control test"""
    print("Simple Position Control Test")
    print("============================")

    motor = MotorController()

    # Zero position
    motor.zero_position()
    print(".2f")

    # Test a few key positions
    test_positions = [45, -45, 90, 0]

    for target_pos in test_positions:
        print(f"\nMoving to {target_pos}°...")

        motor.target_position = target_pos
        motor.control_mode = "position"

        start_time = time.time()
        last_print = 0

        while time.time() - start_time < 10:  # 10 second timeout
            motor.position_control()
            current_pos = motor.get_position_degrees()
            error = abs(current_pos - target_pos)

            # Print progress every second
            if time.time() - last_print >= 1.0:
                print(".2f")
                last_print = time.time()

            # Success if within 3 degrees
            if error < 3.0:
                print(".2f")
                break

            time.sleep(0.01)

        # Final status
        final_pos = motor.get_position_degrees()
        final_error = abs(final_pos - target_pos)
        print(".2f")

        if final_error < 3.0:
            print("✓ SUCCESS")
        else:
            print("✗ TIMEOUT - position not reached")

        time.sleep(1)  # Pause between tests

    motor.stop_motor()
    print("\nTest complete!")

def encoder_check():
    """Quick encoder check"""
    print("\nQuick Encoder Check")
    print("===================")

    motor = MotorController()

    print("Starting encoder count:", motor.encoder_count)
    print("Starting position:", ".2f")

    # Wait 2 seconds to see if there's any drift
    time.sleep(2)

    print("After 2 seconds - count:", motor.encoder_count)
    print("After 2 seconds - position:", ".2f")

    motor.stop_motor()

if __name__ == "__main__":
    encoder_check()
    simple_position_test()
