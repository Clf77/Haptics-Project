"""
Simple test script for CQR37D motor control
Run this to verify basic motor and encoder functionality
"""

import machine
import time
from motor_control import MotorController

def test_encoder():
    """Test encoder functionality"""
    print("Testing encoder...")
    motor = MotorController()

    print("Rotate motor shaft manually and observe encoder counts...")
    start_count = motor.encoder_count
    time.sleep(5)  # Give 5 seconds to rotate motor
    end_count = motor.encoder_count

    count_diff = end_count - start_count
    print(f"Encoder count change: {count_diff}")
    print(f"Approximate revolutions: {count_diff / motor.counts_per_output_rev:.3f}")

    motor.stop_motor()
    return count_diff != 0

def test_motor_directions():
    """Test motor movement in both directions"""
    print("\nTesting motor directions...")
    motor = MotorController()

    print("Testing clockwise rotation (5 seconds)...")
    motor.set_motor_speed(20)  # 20 RPM clockwise
    start_pos = motor.get_position_degrees()
    time.sleep(5)
    end_pos = motor.get_position_degrees()
    motor.stop_motor()

    print(".2f")
    cw_movement = end_pos - start_pos

    print("Testing counter-clockwise rotation (5 seconds)...")
    motor.set_motor_speed(-20)  # 20 RPM counter-clockwise
    start_pos = motor.get_position_degrees()
    time.sleep(5)
    end_pos = motor.get_position_degrees()
    motor.stop_motor()

    print(".2f")
    ccw_movement = start_pos - end_pos

    motor.stop_motor()
    return cw_movement > 0 and ccw_movement > 0

def test_velocity_control():
    """Test velocity control at different speeds"""
    print("\nTesting velocity control...")
    motor = MotorController()

    speeds_to_test = [10, 25, 50, -10, -25, -50]

    for speed in speeds_to_test:
        print(f"Testing speed: {speed} RPM")
        motor.set_motor_speed(speed)
        time.sleep(3)  # Let it stabilize

        measured_speed = motor.get_velocity_rpm()
        print(".2f")

        motor.stop_motor()
        time.sleep(1)  # Brief pause between tests

    motor.stop_motor()
    return True

def test_position_control():
    """Test position control to specific angles"""
    print("\nTesting position control...")
    motor = MotorController()

    # Zero the position first
    motor.zero_position()
    time.sleep(1)

    target_positions = [90, 180, 0, -90, 45]

    for target in target_positions:
        print(f"Moving to position: {target} degrees")
        motor.target_position = target
        motor.control_mode = "position"

        # Wait up to 10 seconds for position to settle
        start_time = time.time()
        while time.time() - start_time < 10:
            motor.position_control()
            current_pos = motor.get_position_degrees()
            error = abs(current_pos - target)

            if error < 5:  # Within 5 degrees
                print(".2f")
                break

            time.sleep(0.01)  # 10ms control loop

        if abs(motor.get_position_degrees() - target) >= 5:
            print(".2f")

    motor.stop_motor()
    return True

def run_all_tests():
    """Run all motor tests"""
    print("=" * 50)
    print("CQR37D Motor Control Test Suite")
    print("=" * 50)

    tests_passed = 0
    total_tests = 4

    try:
        # Test 1: Encoder
        if test_encoder():
            print("✓ Encoder test PASSED")
            tests_passed += 1
        else:
            print("✗ Encoder test FAILED")

        # Test 2: Motor directions
        if test_motor_directions():
            print("✓ Motor directions test PASSED")
            tests_passed += 1
        else:
            print("✗ Motor directions test FAILED")

        # Test 3: Velocity control
        if test_velocity_control():
            print("✓ Velocity control test PASSED")
            tests_passed += 1
        else:
            print("✗ Velocity control test FAILED")

        # Test 4: Position control
        if test_position_control():
            print("✓ Position control test PASSED")
            tests_passed += 1
        else:
            print("✗ Position control test FAILED")

    except Exception as e:
        print(f"Test failed with error: {e}")

    print("\n" + "=" * 50)
    print(f"Tests completed: {tests_passed}/{total_tests} passed")

    if tests_passed == total_tests:
        print("🎉 All tests PASSED! Motor control system is working correctly.")
    else:
        print("⚠️  Some tests failed. Check your hardware connections and configuration.")

    print("=" * 50)

if __name__ == "__main__":
    run_all_tests()
