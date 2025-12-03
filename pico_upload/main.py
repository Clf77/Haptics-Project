"""
Main entry point for Pico - auto-runs on boot
Starts the motor control interface that listens for serial commands
"""

import sys
from motor_control import MotorController
import time
import select

print("Raspberry Pi Pico CQR37D Motor Controller")
print("==========================================")

# SAFE BOOT DELAY
print("Safe Boot: Waiting 3 seconds... (Press Ctrl+C to interrupt)")
time.sleep(3.0)
print("Starting...")

# Initialize motor controller
print("Starting motor control interface...")
motor = MotorController()

# Variables to track state
control_mode = "velocity"
target_velocity = 0.0
target_position = 0.0
last_control_time = time.ticks_ms()

print("Motor control ready. Waiting for commands...")
print("Commands: vel <rpm>, pos <degrees>, hold, spring_wall <forceN> <active>, stop, status")

# Non-blocking read loop so the control loop can keep running at ~100Hz
while True:
    try:
        if select.select([sys.stdin], [], [], 0)[0]:
            line = sys.stdin.readline()
            if line:
                line = line.strip()
                if not line:
                    continue

                parts = line.split()
                cmd = parts[0].lower()

                if cmd == "vel" and len(parts) == 2:
                    target_velocity = float(parts[1])
                    motor.target_velocity = target_velocity
                    motor.control_mode = "velocity"
                    control_mode = motor.control_mode
                    print(f"OK: Velocity set to {target_velocity} RPM")

                elif cmd == "pos" and len(parts) == 2:
                    target_position = float(parts[1])
                    motor.target_position = target_position
                    motor.control_mode = "position"
                    control_mode = motor.control_mode
                    # Reset PID integral when starting new position command
                    motor.integral_error = 0.0
                    motor.last_position_error = 0.0
                    print(f"OK: Moving to {target_position} degrees")

                elif cmd == "hold":
                    motor.hold_position_here()
                    control_mode = motor.control_mode

                elif cmd == "spring_wall":
                    try:
                        if len(parts) < 3:
                            print("ERROR: spring_wall command requires at least force and active arguments.")
                            continue
                        
                        force = float(parts[1])
                        wall_active = int(parts[2])
                        freq = 10.0
                        yield_force = 50.0 # Default yield force
                        
                        if len(parts) > 3:
                            freq = float(parts[3])
                        if len(parts) > 4:
                            yield_force = float(parts[4])
                            
                        motor.set_spring_wall(force, wall_active, freq, yield_force)
                        print(f"OK: Spring wall set: {force}N, Active: {wall_active}, Freq: {freq}Hz, Yield: {yield_force}N")
                    except ValueError:
                        print("ERROR: Invalid spring_wall arguments. Usage: spring_wall <forceN> <active> [freqHz] [yieldN]")
                    control_mode = motor.control_mode

                elif cmd == "stop":
                    motor.stop_motor()
                    control_mode = motor.control_mode
                    print("OK: Motor stopped")

                elif cmd == "status":
                    pos = motor.get_position_degrees()
                    vel = motor.get_velocity_rpm()
                    status_line = f"Position: {pos:.2f} degrees, Velocity: {vel:.2f} RPM, Mode: {motor.control_mode}"
                    if motor.wall_engaged:
                        status_line += f", Wall @ {motor.wall_contact_position_deg:.2f}°, dir={motor.wall_direction:+d}, force={motor.wall_force_newtons:.1f}N"
                    print(status_line)

                elif cmd == "zero":
                    motor.zero_position()
                    print("OK: Position zeroed")

                elif cmd == "haptic" and len(parts) == 2:
                    brake_percent = float(parts[1])
                    motor.set_haptic_feedback(brake_percent)
                    print(f"OK: Haptic feedback set to {brake_percent*100:.1f}%")

                elif cmd == "force" and len(parts) == 3:
                    force_value = float(parts[1])
                    motor_rpm = float(parts[2])
                    motor.set_force_feedback(force_value, motor_rpm)
                    print(f"OK: Force feedback set to {force_value:.2f}N at {motor_rpm:.1f} RPM")

                elif cmd == "raw" and len(parts) == 4:
                    motor.set_raw_driver(parts[1], parts[2], parts[3])
                    print(f"OK: Raw driver set")

                else:
                    print(f"ERROR: Unknown command: {line}")

    except Exception as e:
        print(f"ERROR: {e}")

    # Run control loop at ~100Hz
    now = time.ticks_ms()
    if time.ticks_diff(now, last_control_time) >= 10:
        if motor.control_mode == "position":
            motor.position_control()
        elif motor.control_mode == "velocity":
            motor.velocity_control()
        elif motor.control_mode == "virtual_wall":
            motor.virtual_wall_control()
        last_control_time = now

    # Keep local mode tracker in sync with motor state
    control_mode = motor.control_mode

    # Small delay to prevent busy waiting, but keep loop fast
    # 100us sleep allows for >1kHz loop rate
    time.sleep_us(100)
