#!/usr/bin/env python3
"""
Setup script for Integrated Haptic Lathe System
Installs dependencies and configures the system
"""

import subprocess
import sys
import os
import platform
from pathlib import Path

def run_command(cmd, description):
    """Run a command and return success status"""
    print(f"Running: {description}")
    try:
        result = subprocess.run(cmd, shell=True, check=True,
                              capture_output=True, text=True)
        print("✓ Success")
        return True
    except subprocess.CalledProcessError as e:
        print(f"✗ Failed: {e}")
        if e.stdout:
            print(f"Output: {e.stdout}")
        if e.stderr:
            print(f"Error: {e.stderr}")
        return False

def check_python_version():
    """Check Python version compatibility"""
    if sys.version_info < (3, 6):
        print("✗ Python 3.6 or higher required")
        return False
    print(f"✓ Python {sys.version.split()[0]}")
    return True

def install_python_dependencies():
    """Install required Python packages"""
    packages = ["pyserial"]
    for package in packages:
        if not run_command(f"pip install {package}",
                          f"Installing {package}"):
            return False
    return True

def check_processing_installation():
    """Check if Processing is installed"""
    system = platform.system()

    if system == "Darwin":  # macOS
        processing_app = Path("/Applications/Processing.app")
        if processing_app.exists():
            print("✓ Processing found at /Applications/Processing.app")
            return True
        else:
            print("✗ Processing not found in /Applications")
            print("Please download and install Processing from: https://processing.org/")
            return False

    elif system == "Linux":
        # Check for processing command
        if run_command("which processing", "Checking for Processing"):
            return True
        else:
            print("✗ Processing not found")
            print("Please install Processing from: https://processing.org/")
            return False

    elif system == "Windows":
        # Check common installation paths
        paths = [
            "C:\\Program Files\\Processing\\processing.exe",
            "C:\\Program Files (x86)\\Processing\\processing.exe"
        ]
        for path in paths:
            if Path(path).exists():
                print(f"✓ Processing found at {path}")
                return True

        print("✗ Processing not found in standard locations")
        print("Please install Processing from: https://processing.org/")
        return False

    return False

def check_serial_ports():
    """Check for available serial ports"""
    try:
        import serial.tools.list_ports
        ports = list(serial.tools.list_ports.comports())
        if ports:
            print("✓ Serial ports found:")
            for port in ports:
                print(f"  - {port.device}: {port.description}")
            return True
        else:
            print("! No serial ports found")
            print("  This is OK if you're using the local motor controller")
            return True
    except ImportError:
        print("! pyserial not available for port check")
        return True

def create_config_file():
    """Create configuration file"""
    config_content = """# Integrated Haptic Lathe System Configuration
# Edit these values based on your setup

[serial_ports]
# Serial port for GUI communication (leave empty for auto-detection)
gui_port =

# Serial port for Pico motor controller (leave empty for auto-detection)
pico_port =

[motor_config]
# Motor encoder counts per revolution (fixed for CQR37D)
encoder_cpr = 64

# Gear ratio of your motor
gear_ratio = 30.0

# Maximum RPM for your motor/voltage combination
max_rpm = 150.0

[safety_limits]
# Maximum velocity (RPM)
max_velocity = 100.0

# Maximum position error before safety stop (degrees)
max_position_error = 10.0

# Heartbeat timeout (seconds)
heartbeat_timeout = 5.0

[gui_config]
# GUI update rate (Hz)
update_rate = 10

# Enable physical input by default
physical_input_default = true
"""

    try:
        with open("lathe_config.ini", "w") as f:
            f.write(config_content)
        print("✓ Configuration file created: lathe_config.ini")
        return True
    except Exception as e:
        print(f"✗ Failed to create config file: {e}")
        return False

def check_file_permissions():
    """Check file permissions for execution"""
    files_to_check = [
        "run_integrated_system.py",
        "integrated_lathe_controller.py"
    ]

    for file in files_to_check:
        if os.path.exists(file):
            # Make executable on Unix systems
            if platform.system() != "Windows":
                try:
                    os.chmod(file, 0o755)
                    print(f"✓ Set executable permissions for {file}")
                except Exception as e:
                    print(f"! Could not set permissions for {file}: {e}")
        else:
            print(f"! File not found: {file}")

    return True

def main():
    """Main setup function"""
    print("Integrated Haptic Lathe System Setup")
    print("=" * 40)

    success = True

    # Check Python version
    if not check_python_version():
        success = False

    # Install Python dependencies
    if not install_python_dependencies():
        success = False

    # Check Processing installation
    if not check_processing_installation():
        success = False

    # Check serial ports
    check_serial_ports()

    # Create configuration file
    if not create_config_file():
        success = False

    # Check file permissions
    check_file_permissions()

    print("\n" + "=" * 40)
    if success:
        print("✓ Setup completed successfully!")
        print("\nNext steps:")
        print("1. Connect your motor controller and Pico")
        print("2. Run: python run_integrated_system.py")
        print("3. The GUI should open automatically")
        print("\nFor manual testing:")
        print("- Run motor controller: python motor_control.py")
        print("- Run GUI separately: Use Processing IDE to open Haptic_Lathe_GUI_Integrated.pde")
    else:
        print("✗ Setup completed with errors")
        print("Please resolve the issues above and try again")

    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
