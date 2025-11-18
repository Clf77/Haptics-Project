# Quick Test Commands for Motor Control

# Basic motor test (run in MicroPython REPL)
from motor_control import MotorController
motor = MotorController()

# Test encoder (rotate motor manually)
start = motor.encoder_count
# Rotate motor 1 full turn manually
end = motor.encoder_count
print(f'Counts: {end - start}')

# Test velocity control
motor.set_motor_speed(20)  # 20 RPM
time.sleep(3)
print(f'Speed: {motor.get_velocity_rpm()} RPM')
motor.stop_motor()

# Test position control
motor.zero_position()
motor.target_position = 90
motor.control_mode = 'position'
# Motor should move to 90 degrees

motor.stop_motor()

