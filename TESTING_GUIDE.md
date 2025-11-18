# Motor Control Testing Guide

This guide will help you test and verify your CQR37D motor control system step by step.

## Prerequisites

1. **Hardware Setup**: Ensure all connections are made correctly:
   - Encoder A (white) → Pico pin 9 (GP8)
   - Encoder B (yellow) → Pico pin 10 (GP9)
   - Motor ENA → Pico pin 1 (GP0)
   - Motor IN1 → Pico pin 2 (GP1)
   - Power supply connected to motor controller

2. **Software Setup**: Upload all files to your Pico:
   - `motor_control.py`
   - `test_motor.py`
   - `calibrate_motor.py`
   - `quick_test.py`

## Quick Start Test

### Method 1: REPL Testing (Recommended for beginners)

1. Open Thonny IDE and connect to your Pico
2. Open the REPL (bottom panel)
3. Run these commands one by one:

```python
# Import and create motor controller
from motor_control import MotorController
motor = MotorController()

# Test encoder by rotating motor manually
print("Rotate motor shaft now...")
start_count = motor.encoder_count
# Rotate motor 1-2 full turns manually
import time
time.sleep(3)  # Give yourself time to rotate
end_count = motor.encoder_count
print(f"Count change: {end_count - start_count}")

# Test motor movement
motor.set_motor_speed(10)  # Slow speed
time.sleep(2)
print(f"Current speed: {motor.get_velocity_rpm()} RPM")
motor.stop_motor()
```

### Method 2: Full Test Suite

1. In Thonny, run `test_motor.py`
2. Follow the on-screen instructions
3. The test will check:
   - Encoder functionality
   - Motor direction control
   - Velocity control accuracy
   - Position control accuracy

## Detailed Testing Procedures

### 1. Encoder Test

**Goal**: Verify encoder is reading correctly

```python
from motor_control import MotorController
motor = MotorController()

# Method A: Manual rotation
print("Starting count:", motor.encoder_count)
print("Rotate motor 1 full turn clockwise...")
import time
time.sleep(5)
print("Ending count:", motor.encoder_count)

# Method B: Use test script
exec(open('test_motor.py').read())
# Select encoder test option
```

**Expected Results**:
- Count should increase when rotating clockwise
- Count should decrease when rotating counter-clockwise
- ~1920 counts per revolution (64 CPR × 30:1 gear ratio)

### 2. Motor Direction Test

**Goal**: Verify motor moves in both directions

```python
motor = MotorController()

# Test clockwise
print("Testing clockwise...")
motor.set_motor_speed(15)
time.sleep(3)
motor.stop_motor()

# Test counter-clockwise
print("Testing counter-clockwise...")
motor.set_motor_speed(-15)
time.sleep(3)
motor.stop_motor()
```

**Expected Results**:
- Motor should spin smoothly in both directions
- No unusual noises or vibrations

### 3. Velocity Control Test

**Goal**: Test speed control accuracy

```python
motor = MotorController()

speeds = [10, 20, 30, -10, -20]

for speed in speeds:
    motor.set_motor_speed(speed)
    time.sleep(2)  # Let speed stabilize
    measured = motor.get_velocity_rpm()
    print(f"Target: {speed} RPM, Measured: {measured:.1f} RPM")
    motor.stop_motor()
    time.sleep(1)
```

**Expected Results**:
- Measured speed should be close to target speed
- Allow ±5 RPM tolerance

### 4. Position Control Test

**Goal**: Test PID position control

```python
motor = MotorController()

# Zero position
motor.zero_position()

# Test positions
targets = [45, 90, 180, 0, -90]

for target in targets:
    motor.target_position = target
    motor.control_mode = "position"

    # Wait for movement to complete
    start_time = time.time()
    while time.time() - start_time < 10:
        motor.position_control()
        current = motor.get_position_degrees()
        error = abs(current - target)
        print(f"Target: {target}°, Current: {current:.1f}°, Error: {error:.1f}°")

        if error < 2:  # Within 2 degrees
            print(f"✓ Reached target {target}°")
            break

        time.sleep(0.1)

    motor.stop_motor()
    time.sleep(2)
```

**Expected Results**:
- Motor should move to within 2-5 degrees of target
- Settling time should be reasonable (5-15 seconds)
- No oscillation or instability

## Calibration Procedures

### 1. Encoder Calibration

Run the calibration script:
```python
exec(open('calibrate_motor.py').read())
# Choose option 1
```

This will help you determine the correct gear ratio for your motor.

### 2. Speed Calibration

```python
exec(open('calibrate_motor.py').read())
# Choose option 2
```

This determines your motor's maximum speed capability.

### 3. PID Tuning

```python
exec(open('calibrate_motor.py').read())
# Choose option 3
```

Tune the PID parameters for better position control.

## Troubleshooting

### Motor Doesn't Move
1. Check power supply voltage
2. Verify motor controller connections
3. Try increasing minimum PWM value in code
4. Check motor controller documentation

### Encoder Not Reading
1. Verify encoder pin connections
2. Check encoder power supply (needs 3.3V-24V)
3. Try swapping A/B encoder wires
4. Check for loose connections

### Position Control Oscillates
1. Reduce P (proportional) gain
2. Increase D (derivative) gain
3. Reduce I (integral) gain
4. Check for mechanical backlash

### Velocity Control Inaccurate
1. Adjust max_rpm value in code
2. Check power supply stability
3. Verify encoder CPR and gear ratio
4. Check for mechanical load issues

## Performance Metrics

After successful testing, your system should achieve:

- **Position Accuracy**: ±2-5 degrees
- **Velocity Accuracy**: ±5 RPM
- **Response Time**: <2 seconds for velocity changes
- **Settling Time**: 5-15 seconds for position control
- **Encoder Resolution**: ~0.2 degrees per count (with 30:1 gear ratio)

## Safety Precautions

- Always start with low speeds during testing
- Keep fingers clear of moving parts
- Use appropriate power supply voltage
- Monitor motor and controller temperatures
- Have emergency stop capability ready

## Next Steps

Once testing is complete:
1. Update configuration values in `motor_control.py`
2. Use the main command-line interface for normal operation
3. Integrate with your haptic lathe project
4. Add additional safety features as needed
