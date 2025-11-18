# Raspberry Pi Pico CQR37D Motor Controller

This project provides Python code to control a CQRobot CQR37D DC geared motor with quadrature encoder using a Raspberry Pi Pico microcontroller. It supports both position and velocity control through a command-line interface.

## Hardware Setup

### Required Components
- Raspberry Pi Pico
- CQRobot CQR37D DC Geared Motor with Encoder
- DROK XY-160D Motor Controller (or similar DC motor controller)
- Power supply (appropriate voltage for your motor - typically 6V, 12V, or 24V)

### Pin Connections

| Component | Pico Pin | GPIO | Wire Color (Encoder) |
|-----------|----------|------|---------------------|
| Encoder A | 9 | GP8 | White |
| Encoder B | 10 | GP9 | Yellow |
| Motor ENA | 1 | GP0 | Controller PWM Input |
| Motor IN1 | 2 | GP1 | Controller Direction |

### Motor Controller Setup (DROK XY-160D)
- **ENA**: Connected to Pico GP0 (pin 1) - PWM speed control
- **IN1**: Connected to Pico GP1 (pin 2) - Direction control
- **Power**: Connect appropriate DC voltage to motor controller power terminals
- **Motor**: Connect motor leads to controller output

## Software Setup

### Requirements
- MicroPython installed on Raspberry Pi Pico
- Thonny IDE (recommended) or another MicroPython editor

### Installation
1. Copy `motor_control.py` to your Raspberry Pi Pico
2. Open the file in Thonny or your preferred editor
3. Run the script

## Configuration

### Motor Parameters
Edit these values in the `MotorController.__init__()` method:

```python
self.CPR = 64  # Counts per revolution (fixed for CQR37D)
self.gear_ratio = 30.0  # Your motor's gear ratio (check your motor specs)
self.max_rpm = 150.0  # Maximum RPM for your motor/voltage combination
```

### PID Tuning (for Position Control)
Default PID values are provided, but you may need to tune them:

```python
self.kp = 2.0   # Proportional gain
self.ki = 0.1   # Integral gain
self.kd = 0.05  # Derivative gain
```

## Usage

### Command Line Interface

Run the script and use these commands:

#### Position Control
```
pos <degrees>     - Move to absolute position in degrees
Example: pos 180    (move to 180 degrees)
```

#### Velocity Control
```
vel <rpm>         - Set constant velocity in RPM
Example: vel 50     (spin at 50 RPM clockwise)
Example: vel -30    (spin at 30 RPM counter-clockwise)
```

#### Other Commands
```
stop              - Stop the motor
zero              - Zero the position counter (set current position to 0)
status            - Show current position, velocity, and control mode
pid <kp> <ki> <kd> - Set PID gains for position control
help              - Show all available commands
quit              - Exit the program
```

### Example Usage Session
```
Motor controller initialized
Encoder CPR: 64, Gear ratio: 30.0
Counts per output revolution: 1920.0

Type 'help' for available commands
Current mode: velocity control

vel 30
Velocity control: target = 30 RPM

status
Position: 45.67 degrees
Velocity: 29.85 RPM
Control mode: velocity
Target velocity: 30.00 RPM

pos 90
Position control: target = 90 degrees

status
Position: 89.94 degrees
Velocity: 0.12 RPM
Control mode: position
Target position: 90.00 degrees

stop
Motor stopped

quit
Exiting...
```

## Technical Details

### Encoder
- **Type**: Quadrature encoder with 64 counts per revolution (motor shaft)
- **Resolution**: After gearing, depends on your gear ratio
- **Interface**: Uses hardware interrupts for real-time position tracking

### Motor Control
- **Speed Control**: PWM on ENA pin (1kHz frequency)
- **Direction Control**: Digital output on IN1 pin
- **Deadband Compensation**: Minimum PWM value to overcome motor stall

### Control Modes

#### Velocity Control
- Direct RPM control
- Immediate response to velocity commands
- Good for continuous rotation applications

#### Position Control
- PID-based position control
- Maintains target angular position
- Includes integral windup protection

### Performance Considerations
- **Control Loop**: Runs at 100Hz (10ms intervals)
- **Position Accuracy**: Depends on encoder resolution and PID tuning
- **Maximum Speed**: Limited by motor capabilities and PWM frequency
- **Interrupt Latency**: MicroPython interrupt response time may affect high-speed performance

## Troubleshooting

### Common Issues

1. **Motor not moving**
   - Check power supply voltage and connections
   - Verify motor controller wiring
   - Ensure minimum PWM threshold is set correctly

2. **Inaccurate position**
   - Calibrate encoder count per revolution
   - Tune PID parameters
   - Check for mechanical backlash

3. **Velocity oscillations**
   - Reduce P gain
   - Increase D gain
   - Check encoder signal quality

4. **No encoder feedback**
   - Verify encoder pin connections
   - Check encoder power supply (3.3V-24V)
   - Ensure encoder wires are properly seated

### Calibration

1. **Encoder CPR**: Use the known value (64 for CQR37D)
2. **Gear Ratio**: Measure or check motor specifications
3. **Maximum RPM**: Test under load with your power supply
4. **PID Gains**: Start with low values and increase gradually

## Safety Notes

- **Power Supply**: Use appropriate voltage for your motor
- **Current Limiting**: Ensure your power supply can handle motor stall current
- **Mechanical Limits**: Add physical stops if needed to prevent over-rotation
- **Heat Dissipation**: Monitor motor and controller temperatures during operation

## License

This code is provided as-is for educational and experimental purposes.
