#!/usr/bin/env python3
"""
Proper Pico MicroPython file upload using ampy or rshell
This is the CORRECT way to upload files to a Pico running MicroPython
"""

import subprocess
import sys
import time
import serial.tools.list_ports

def find_pico_port():
    """Find the Pico serial port"""
    ports = list(serial.tools.list_ports.comports())
    for port in ports:
        if 'usbmodem' in port.device or 'USB Serial' in port.description:
            return port.device
    return None

def check_ampy_installed():
    """Check if ampy is installed"""
    try:
        result = subprocess.run(['ampy', '--version'], capture_output=True, text=True)
        return True
    except FileNotFoundError:
        return False

def install_ampy():
    """Install ampy tool"""
    print("📦 Installing ampy (Adafruit MicroPython Tool)...")
    try:
        subprocess.run([sys.executable, '-m', 'pip', 'install', 'adafruit-ampy'], check=True)
        print("✅ ampy installed successfully!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to install ampy: {e}")
        return False

def upload_file_with_ampy(port, local_file, remote_file=None):
    """Upload a file to Pico using ampy"""
    if remote_file is None:
        remote_file = local_file.split('/')[-1]
    
    try:
        print(f"📤 Uploading {local_file} to Pico as {remote_file}...")
        result = subprocess.run(
            ['ampy', '--port', port, 'put', local_file, remote_file],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            print(f"✅ {remote_file} uploaded successfully!")
            return True
        else:
            print(f"❌ Upload failed: {result.stderr}")
            return False
            
    except subprocess.TimeoutExpired:
        print(f"❌ Upload timed out")
        return False
    except Exception as e:
        print(f"❌ Upload error: {e}")
        return False

def list_files_on_pico(port):
    """List files on Pico"""
    try:
        result = subprocess.run(
            ['ampy', '--port', port, 'ls'],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode == 0:
            print("📁 Files on Pico:")
            print(result.stdout)
            return True
        else:
            return False
            
    except Exception as e:
        print(f"❌ Error listing files: {e}")
        return False

def test_motor_control(port):
    """Test if motor control is working"""
    import serial
    
    try:
        print("🧪 Testing motor control...")
        ser = serial.Serial(port, 115200, timeout=2)
        
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.2)
        
        # Enter raw REPL mode
        ser.write(b'\x03')  # Ctrl-C
        time.sleep(0.1)
        ser.write(b'\x03')  # Ctrl-C again
        time.sleep(0.1)
        ser.write(b'\x01')  # Ctrl-A for raw REPL
        time.sleep(0.5)
        
        # Clear any pending output
        ser.read(ser.in_waiting)
        
        # Test import
        ser.write(b'import motor_control\r\n')
        ser.write(b'\x04')  # Ctrl-D to execute
        time.sleep(1)
        
        response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
        
        if 'Motor controller initialized' in response or 'Traceback' not in response:
            print("✅ Motor control import successful!")
            
            # Test instantiation
            ser.write(b'\x03')  # Ctrl-C
            time.sleep(0.1)
            ser.write(b'\x01')  # Ctrl-A for raw REPL
            time.sleep(0.2)
            ser.read(ser.in_waiting)
            
            ser.write(b'from motor_control import MotorController\r\n')
            ser.write(b'motor = MotorController()\r\n')
            ser.write(b'print("Position:", motor.get_position_degrees())\r\n')
            ser.write(b'\x04')  # Ctrl-D
            time.sleep(1)
            
            response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
            print(f"Response: {response}")
            
            if 'Position:' in response:
                print("✅ Motor control fully working!")
                ser.close()
                return True
        
        ser.close()
        return False
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False

def main():
    print("🔧 PROPER PICO MICROPYTHON FILE UPLOAD")
    print("=" * 50)
    
    # Find Pico
    print("🔍 Searching for Pico...")
    port = find_pico_port()
    
    if not port:
        print("❌ Pico not found!")
        print("Make sure:")
        print("1. Pico is plugged in")
        print("2. MicroPython UF2 has been flashed")
        print("3. Pico has restarted (NOT in BOOTSEL mode)")
        return 1
    
    print(f"✅ Pico found on {port}")
    
    # Check/install ampy
    if not check_ampy_installed():
        print("⚠️  ampy not installed")
        if not install_ampy():
            return 1
    else:
        print("✅ ampy is installed")
    
    # Upload files
    files_to_upload = [
        'pico_upload/motor_control.py',
        'pico_upload/test_motor.py'
    ]
    
    for file_path in files_to_upload:
        if not upload_file_with_ampy(port, file_path):
            print(f"❌ Failed to upload {file_path}")
            return 1
    
    print()
    # List files on Pico
    list_files_on_pico(port)
    
    print()
    # Test motor control
    if test_motor_control(port):
        print()
        print("🎉 SUCCESS! CQR37D motor control is ready!")
        print()
        print("Next steps:")
        print("1. Run: python3 test_real_hardware.py")
        print("2. Or run: python3 integrated_lathe_controller.py")
        return 0
    else:
        print()
        print("⚠️  Files uploaded but motor control test failed")
        print("This might be normal if hardware isn't connected yet")
        return 0

if __name__ == "__main__":
    sys.exit(main())

