"""
Automated position control test - tests if position control works without manual input
"""

import time
from motor_control import MotorController

def test_position_accuracy():
    """Test position control accuracy with automated moves"""
    print("Automated Position Control Test")
    print("===============================")

    motor = MotorController()

    # Zero position
    motor.zero_position()
    print(".2f")

    # Test sequence of position moves
    test_positions = [30, 60, 90, 60, 30, 0, -30, -60, 0]

    for i, target_pos in enumerate(test_positions):
        print(f"\nMove {i+1}/{len(test_positions)}: {target_pos}°")

        motor.target_position = target_pos
        motor.control_mode = "position"

        # Run position control for 8 seconds
        start_time = time.time()
        positions = []

        while time.time() - start_time < 8:
            motor.position_control()
            current_pos = motor.get_position_degrees()
            positions.append(current_pos)

            # Print progress every 0.5 seconds
            if int((time.time() - start_time) * 2) % 2 == 0 and len(positions) % 50 == 0:
                print(".2f")

            time.sleep(0.01)

        final_pos = motor.get_position_degrees()
        error = abs(final_pos - target_pos)
        print(".2f")

        if error < 5.0:
            print("✓ Good accuracy")
        elif error < 15.0:
            print("⚠ Moderate accuracy")
        else:
            print("✗ Poor accuracy - check encoder feedback")

        time.sleep(1)  # Brief pause

    motor.stop_motor()
    print("\nAutomated position test complete!")

def test_velocity_vs_position():
    """Compare velocity control vs position control"""
    print("\nVelocity vs Position Control Comparison")
    print("=======================================")

    motor = MotorController()

    print("Testing velocity control: 20 RPM for 5 seconds...")
    motor.target_velocity = 20
    motor.control_mode = "velocity"

    start_time = time.time()
    velocity_readings = []

    while time.time() - start_time < 5:
        motor.velocity_control()
        vel = motor.get_velocity_rpm()
        velocity_readings.append(vel)
        time.sleep(0.1)

    avg_velocity = sum(velocity_readings) / len(velocity_readings)
    print(".2f")

    motor.stop_motor()
    time.sleep(1)

    print("Testing position control: move to 45°...")
    motor.zero_position()
    motor.target_position = 45
    motor.control_mode = "position"

    start_time = time.time()
    position_readings = []

    while time.time() - start_time < 8:
        motor.position_control()
        pos = motor.get_position_degrees()
        position_readings.append(pos)
        time.sleep(0.1)

        if abs(pos - 45) < 3:
            break

    final_pos = motor.get_position_degrees()
    print(".2f")

    motor.stop_motor()

    # Analysis
    if abs(avg_velocity - 20) < 5:
        print("✓ Velocity control working well")
    else:
        print("⚠ Velocity control accuracy needs tuning")

    if abs(final_pos - 45) < 5:
        print("✓ Position control working well")
    else:
        print("⚠ Position control needs encoder feedback tuning")

def main():
    test_position_accuracy()
    test_velocity_vs_position()

if __name__ == "__main__":
    main()
