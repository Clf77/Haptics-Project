"""
Focused position control test to debug encoder feedback
"""

import time
from motor_control import MotorController

def test_position_control():
    """Test position control with encoder feedback"""
    print("Position Control Debug Test")
    print("==========================")

    motor = MotorController()

    # Zero the position first
    print("Zeroing position...")
    motor.zero_position()
    print(".2f")

    # Test simple position moves
    test_positions = [45, 90, 0, -45, -90, 0]

    for target_pos in test_positions:
        print(f"\nMoving to {target_pos} degrees...")

        # Set position control mode
        motor.target_position = target_pos
        motor.control_mode = "position"

        # Wait for movement to complete or timeout
        start_time = time.time()
        timeout = 10  # 10 seconds timeout

        while time.time() - start_time < timeout:
            motor.position_control()
            current_pos = motor.get_position_degrees()
            error = abs(current_pos - target_pos)

            print(".2f")

            # Check if we're close enough to target
            if error < 2.0:  # Within 2 degrees
                print(".2f")
                break

            time.sleep(0.01)  # 10ms control loop

        if abs(motor.get_position_degrees() - target_pos) >= 2.0:
            print(".2f")

        time.sleep(1)  # Brief pause between moves

    motor.stop_motor()
    print("\nPosition control test complete!")

def test_encoder_feedback():
    """Test encoder feedback during manual movement"""
    print("\nEncoder Feedback Test")
    print("=====================")

    motor = MotorController()

    print("Current encoder count:", motor.encoder_count)
    print(".2f")

    print("Manually rotate motor shaft 2 full turns clockwise, then press Enter...")
    input()

    after_cw_count = motor.encoder_count
    after_cw_pos = motor.get_position_degrees()

    print(f"After clockwise: count={after_cw_count}, position={after_cw_pos:.2f}°")

    print("Now rotate 2 full turns counter-clockwise, then press Enter...")
    input()

    after_ccw_count = motor.encoder_count
    after_ccw_pos = motor.get_position_degrees()

    print(f"After counter-clockwise: count={after_ccw_count}, position={after_ccw_pos:.2f}°")

    # Calculate expected counts (2 revolutions * gear ratio * CPR)
    expected_counts = 2 * motor.counts_per_output_rev
    print(f"Expected count change for 2 revolutions: {expected_counts}")

    # Analyze results
    if abs(after_cw_count) > 100:  # Some movement detected
        print("✓ Encoder feedback working - motor movement detected!")
    else:
        print("✗ Encoder feedback not working - minimal/no movement detected")

    motor.stop_motor()

def main():
    print("Motor Position Control & Encoder Debug")
    print("======================================")

    test_encoder_feedback()
    test_position_control()

if __name__ == "__main__":
    main()
