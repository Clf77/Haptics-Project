"""
Main entry point for Pico - auto-runs on boot
Starts the motor control interface that listens for serial commands
"""

import sys
from motor_control import MotorController
import time

# Initialize motor controller
print("Starting motor control interface...")
motor = MotorController()

# Variables to track state
control_mode = "idle"
target_velocity = 0.0
target_position = 0.0

print("Motor control ready. Waiting for commands...")
print("Commands: vel <rpm>, pos <degrees>, stop, status")

# Simple approach: read from stdin in a loop
# In MicroPython, sys.stdin.readline() will block until a line is available
# This is actually fine for our use case - it will wait for commands
while True:
    try:
        # Read a line (this will block until input is available)
        line = sys.stdin.readline()
        if line:
            line = line.strip()
            if line:
                parts = line.split()
                if parts:
                    cmd = parts[0].lower()
                    
                    if cmd == "vel" and len(parts) == 2:
                        target_velocity = float(parts[1])
                        motor.set_motor_speed(target_velocity)
                        control_mode = "velocity"
                        print(f"OK: Velocity set to {target_velocity} RPM")
                        
                    elif cmd == "pos" and len(parts) == 2:
                        target_position = float(parts[1])
                        motor.target_position = target_position
                        motor.control_mode = "position"
                        control_mode = "position"
                        # Reset PID integral when starting new position command
                        motor.integral_error = 0.0
                        motor.last_position_error = 0.0
                        print(f"OK: Moving to {target_position} degrees")
                        
                    elif cmd == "stop":
                        motor.stop_motor()
                        control_mode = "idle"
                        print("OK: Motor stopped")
                        
                    elif cmd == "status":
                        # Encoder updates automatically via interrupts
                        pos = motor.get_position_degrees()
                        vel = motor.get_velocity_rpm()
                        print(f"Position: {pos:.2f} degrees, Velocity: {vel:.2f} RPM, Mode: {control_mode}")
                        
                    elif cmd == "zero":
                        motor.zero_position()
                        print("OK: Position zeroed")
                        
                    elif cmd == "haptic" and len(parts) == 2:
                        brake_percent = float(parts[1])
                        motor.set_haptic_feedback(brake_percent)
                        print(f"OK: Haptic feedback set to {brake_percent*100:.1f}%")
                        
                    else:
                        print(f"ERROR: Unknown command: {line}")
                        
    except Exception as e:
        print(f"ERROR: {e}")
    
    # Run control loop if in position mode
    if control_mode == "position":
        motor.position_control()
    
    # Small delay to prevent CPU spinning (only if no input was available)
    # Note: readline() blocks, so this only runs if there was an exception
    time.sleep(0.01)
