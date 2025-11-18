"""
Motor calibration script for CQR37D
Helps determine correct gear ratio and PID parameters
"""

import machine
import time
from motor_control import MotorController

def calibrate_encoder_counts():
    """Calibrate encoder counts per revolution"""
    print("Encoder Calibration")
    print("===================")
    print("This will help determine your motor's gear ratio.")
    print("Make sure your motor can rotate freely.")
    print()

    motor = MotorController()

    print("Current configuration:")
    print(f"Encoder CPR: {motor.CPR}")
    print(f"Gear ratio: {motor.gear_ratio}")
    print(f"Calculated counts per output revolution: {motor.counts_per_output_rev}")
    print()

    input("Press Enter to start calibration, then rotate motor exactly 1 full revolution...")

    start_count = motor.encoder_count
    print(f"Starting count: {start_count}")

    input("Rotate motor 1 full revolution (360 degrees), then press Enter...")

    end_count = motor.encoder_count
    print(f"Ending count: {end_count}")

    count_diff = abs(end_count - start_count)
    print(f"Count difference: {count_diff}")
    print()

    if count_diff > 0:
        calculated_gear_ratio = count_diff / motor.CPR
        print(".3f")
        print(f"Suggested gear ratio: {calculated_gear_ratio:.1f}")
        print()
        print("Update your motor_control.py file with:")
        print(f"self.gear_ratio = {calculated_gear_ratio:.1f}")
    else:
        print("No encoder movement detected. Check your encoder connections.")

    motor.stop_motor()

def calibrate_max_speed():
    """Calibrate maximum motor speed"""
    print("\nSpeed Calibration")
    print("=================")
    print("This will help determine your motor's maximum speed.")
    print()

    motor = MotorController()

    print("Testing different PWM duty cycles...")
    print("Speed (RPM) | PWM Duty | Voltage equiv")
    print("------------|----------|--------------")

    # Test different duty cycles
    test_duties = [0.2, 0.4, 0.6, 0.8, 1.0]

    max_measured_speed = 0

    for duty in test_duties:
        duty_value = int(duty * 65535)
        motor.motor_ena.duty_u16(duty_value)
        motor.motor_in1.value(1)  # Forward direction

        # Let motor stabilize
        time.sleep(3)

        # Measure speed over 2 seconds
        speeds = []
        for _ in range(20):
            speed = motor.get_velocity_rpm()
            speeds.append(speed)
            time.sleep(0.1)

        avg_speed = sum(speeds) / len(speeds)
        max_measured_speed = max(max_measured_speed, avg_speed)

        voltage_equiv = duty * 100  # Assuming full scale is motor voltage
        print("8.1f")

        motor.stop_motor()
        time.sleep(2)  # Cool down between tests

    print(f"\nMaximum measured speed: {max_measured_speed:.1f} RPM")
    print("Update your motor_control.py file with:")
    print(f"max_rpm = {max_measured_speed:.0f}")

    motor.stop_motor()

def tune_pid():
    """Interactive PID tuning"""
    print("\nPID Tuning")
    print("==========")
    print("This will help tune your PID parameters for position control.")
    print()

    motor = MotorController()

    # Default PID values
    kp = motor.kp
    ki = motor.ki
    kd = motor.kd

    print(f"Current PID values: Kp={kp}, Ki={ki}, Kd={kd}")
    print()

    while True:
        print("PID Tuning Options:")
        print("1. Test current PID values")
        print("2. Adjust Kp (proportional)")
        print("3. Adjust Ki (integral)")
        print("4. Adjust Kd (derivative)")
        print("5. Auto-tune (experimental)")
        print("6. Exit PID tuning")
        print()

        choice = input("Enter your choice (1-6): ").strip()

        if choice == "1":
            # Test current PID
            print("Testing current PID values...")
            test_position = 90.0

            motor.target_position = test_position
            motor.control_mode = "position"

            print(f"Moving to {test_position} degrees...")

            start_time = time.time()
            while time.time() - start_time < 15:  # 15 second test
                motor.position_control()
                current_pos = motor.get_position_degrees()
                print(".2f")
                time.sleep(0.1)

                if abs(current_pos - test_position) < 2:  # Good enough
                    break

            motor.stop_motor()
            print("Test complete.")

        elif choice in ["2", "3", "4"]:
            param_name = {"2": "Kp", "3": "Ki", "4": "Kd"}[choice]
            current_value = {"2": kp, "3": ki, "4": kd}[choice]

            try:
                new_value = float(input(f"Enter new {param_name} value (current: {current_value}): "))
                if choice == "2":
                    kp = new_value
                    motor.kp = kp
                elif choice == "3":
                    ki = new_value
                    motor.ki = ki
                elif choice == "4":
                    kd = new_value
                    motor.kd = kd

                print(f"{param_name} updated to {new_value}")

            except ValueError:
                print("Invalid value. Please enter a number.")

        elif choice == "5":
            print("Auto-tuning PID (this may take a while)...")
            # Simple auto-tune using Ziegler-Nichols method
            print("Auto-tuning not yet implemented. Try manual tuning.")

        elif choice == "6":
            print("Exiting PID tuning.")
            print(f"Final PID values: Kp={kp}, Ki={ki}, Kd={kd}")
            print("Update your motor_control.py file with:")
            print(f"self.kp = {kp}")
            print(f"self.ki = {ki}")
            print(f"self.kd = {kd}")
            break

        else:
            print("Invalid choice. Please enter 1-6.")

        print()

    motor.stop_motor()

def main():
    print("CQR37D Motor Calibration Utility")
    print("=================================")
    print()

    while True:
        print("Calibration Options:")
        print("1. Calibrate encoder counts per revolution")
        print("2. Calibrate maximum motor speed")
        print("3. Tune PID parameters")
        print("4. Exit calibration")
        print()

        choice = input("Enter your choice (1-4): ").strip()

        if choice == "1":
            calibrate_encoder_counts()
        elif choice == "2":
            calibrate_max_speed()
        elif choice == "3":
            tune_pid()
        elif choice == "4":
            print("Exiting calibration utility.")
            break
        else:
            print("Invalid choice. Please enter 1-4.")

        print()

if __name__ == "__main__":
    main()
