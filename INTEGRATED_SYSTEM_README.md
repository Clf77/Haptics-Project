# Integrated Haptic Lathe System

This project integrates a Processing-based GUI simulator with a physical motor controller to create a complete haptic lathe training system. The handle wheel on the motor becomes the primary input device for tool positioning.

## System Architecture

```
┌─────────────────┐    Serial     ┌──────────────────┐    Serial     ┌─────────────────┐
│   Processing    │ ────────────► │   Python Bridge  │ ◄───────────► │   Raspberry Pi  │
│      GUI        │               │   Controller     │               │      Pico       │
│                 │ ◄──────────── │                  │ ─────────────► │   Motor Control │
└─────────────────┘               └──────────────────┘               └─────────────────┘
         ▲                              ▲                                      │
         │                              │                                      ▼
         └──────────────────────────────┘                            ┌─────────────────┐
                                                         Handle      │    CQR37D       │
                                                         Wheel       │   Geared Motor  │
                                                         Position     │   + Encoder     │
                                                                      └─────────────────┘
```

## Features

- **Physical Handle Wheel Input**: Motor encoder provides real-time position feedback
- **Haptic Feedback**: Motor can provide force feedback (future enhancement)
- **Training Modes**: Facing, Turning, and Boring operations
- **Skill Levels**: Beginner, Intermediate, Advanced with different assistance levels
- **Safety Features**: Emergency stop, position limits, heartbeat monitoring
- **Dual Input Modes**: Toggle between physical handle wheel and mouse control

## Hardware Requirements

### Required Components
- Raspberry Pi Pico (or compatible microcontroller)
- CQR37D DC Geared Motor with Encoder
- DC Motor Controller (DROK XY-160D or similar)
- Handle wheel attached to motor shaft
- Power supply appropriate for motor (6V-24V DC)
- Computer with Processing IDE installed

### Pin Connections

| Component | Pico Pin | GPIO | Wire Color |
|-----------|----------|------|------------|
| Encoder A | 9 | GP8 | White |
| Encoder B | 10 | GP9 | Yellow |
| Motor ENA | 1 | GP0 | PWM Speed |
| Motor IN1 | 2 | GP1 | Direction |

## Software Setup

### Quick Setup
```bash
# Run setup script
python setup_integrated_system.py

# Run the integrated system
python run_integrated_system.py
```

### Manual Setup

1. **Install Dependencies**
   ```bash
   pip install pyserial
   ```

2. **Install Processing IDE**
   - Download from: https://processing.org/
   - macOS: Install to /Applications/
   - Linux/Windows: Install to system path

3. **Upload Motor Control to Pico**
   ```bash
   # Use Thonny or your preferred MicroPython editor
   # Upload motor_control.py to your Pico
   ```

## Configuration

Edit `lathe_config.ini` to customize settings:

```ini
[serial_ports]
gui_port = /dev/ttyACM0    # Auto-detected if empty
pico_port = /dev/ttyACM1   # Auto-detected if empty

[motor_config]
encoder_cpr = 64           # Encoder counts per revolution
gear_ratio = 30.0          # Your motor's gear ratio
max_rpm = 150.0           # Maximum motor RPM

[safety_limits]
max_velocity = 100.0      # Safety velocity limit
max_position_error = 10.0 # Position error threshold
heartbeat_timeout = 5.0   # Connection timeout
```

## Usage

### Starting the System

```bash
python run_integrated_system.py
```

This will:
1. Start the Python bridge controller
2. Launch the Processing GUI
3. Establish serial communication between components

### GUI Controls

- **Training Scenario Buttons**: Select Facing, Turning, or Boring operations
- **Skill Level**: Choose Beginner, Intermediate, or Advanced
- **Control Buttons**:
  - Reset: Reset workpiece and zero positions
  - Zero X/Z: Zero position readouts
  - Show Toolpath: Toggle cutting path visualization

### Keyboard Shortcuts

- **Spacebar**: Emergency stop (sends stop command to motor)
- **P**: Toggle between physical handle wheel and mouse input
- **Ctrl+C**: Shutdown entire system

### Physical Operation

1. **Power on** motor controller and ensure proper voltage
2. **Start system** using the launcher script
3. **Select training mode** in the GUI
4. **Turn handle wheel** to position the cutting tool
5. **Monitor position** in real-time on the GUI display

## Communication Protocol

### GUI → Bridge (JSON)
```json
{"type": "mode_change", "mode": "facing", "skill_level": "beginner"}
{"type": "set_parameters", "spindle_rpm": 500, "feed_rate": 0.005}
{"type": "emergency_stop"}
{"type": "zero_position", "axis": "x"}
{"type": "reset"}
```

### Bridge → GUI (JSON)
```json
{
  "type": "status_update",
  "handle_wheel_position": 45.67,
  "mode": "facing",
  "skill_level": "beginner",
  "emergency_stop": false,
  "spindle_rpm": 500,
  "feed_rate": 0.005,
  "timestamp": 1640995200.0
}
```

### Bridge ↔ Pico (Text Commands)
```
pos 180          # Move to 180 degrees
vel 50           # Set velocity to 50 RPM
stop             # Stop motor
status           # Get current status
zero             # Zero position
```

## Safety Features

- **Emergency Stop**: Spacebar or GUI button immediately stops motor
- **Position Limits**: Software limits prevent over-rotation
- **Heartbeat Monitoring**: Detects communication loss
- **Velocity Limiting**: Maximum RPM enforced in software
- **Error Detection**: Position error monitoring with automatic shutdown

## Troubleshooting

### Common Issues

1. **"No serial port found"**
   - Check USB connections
   - Try different USB ports
   - Ensure Pico is properly flashed with MicroPython

2. **Motor not responding**
   - Verify power supply voltage
   - Check motor controller wiring
   - Confirm PWM pin connections

3. **GUI won't start**
   - Ensure Processing IDE is installed
   - Check sketch file path
   - Try running Processing manually

4. **Position inaccurate**
   - Calibrate encoder CPR and gear ratio
   - Check for mechanical backlash
   - Verify encoder signal quality

### Debug Mode

Run individual components for testing:

```bash
# Test motor controller only
python motor_control.py

# Test bridge only (no Pico connected)
python integrated_lathe_controller.py

# Test GUI only (no bridge connected)
# Open Haptic_Lathe_GUI_Integrated.pde in Processing IDE
```

## Development

### Adding New Features

1. **New GUI Controls**: Add to `Haptic_Lathe_GUI_Integrated.pde`
2. **Motor Commands**: Extend `integrated_lathe_controller.py`
3. **Safety Features**: Add to safety monitoring in bridge controller

### Code Structure

- `integrated_lathe_controller.py`: Python bridge between GUI and motor
- `Haptic_Lathe_GUI_Integrated.pde`: Processing GUI with serial communication
- `run_integrated_system.py`: System launcher and process manager
- `setup_integrated_system.py`: Dependency installer and configurator

## Future Enhancements

- **Haptic Feedback**: Motor resistance based on cutting forces
- **Force Sensing**: Measure actual cutting forces
- **Advanced Training**: Path following and skill assessment
- **Multi-axis Control**: Add X and Z axis motors
- **Network Operation**: Web-based interface for remote training

## License

This project is provided for educational and experimental purposes.
