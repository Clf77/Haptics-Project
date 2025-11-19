#!/usr/bin/env python3
"""
Upload Python files to Raspberry Pi Pico via serial connection
"""

import serial
import time
import sys

def upload_file_to_pico(port, filename, content):
    """Upload a Python file to the Pico via serial"""
    try:
        ser = serial.Serial(port, 115200, timeout=2)
        print(f"Connected to {port}")

        # Clear any pending data
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        filename_only = filename.split('/')[-1]  # Get just the filename
        print(f"Uploading {filename_only} ({len(content)} chars)...")

        # Send the entire file content at once using proper MicroPython syntax
        # First, encode the content to handle special characters
        content_escaped = content.replace('\\', '\\\\').replace('"', '\\"').replace("'", "\\'")

        # Send command to write the entire file
        command = f"with open('{filename_only}', 'w') as f: f.write('''{content_escaped}''')\n"

        # Send the command
        ser.write(command.encode())
        time.sleep(0.2)  # Wait for command to process

        print(f"✅ {filename_only} uploaded successfully!")

        # Test the import by sending a simple import command
        ser.write(b"import sys\n")
        time.sleep(0.1)

        ser.write(f"try:\n    import {filename_only.replace('.py', '')}\n    print('Import successful')\nexcept ImportError as e:\n    print('Import failed:', e)\n".encode())
        time.sleep(0.5)

        # Read response
        response = ""
        start_time = time.time()
        while time.time() - start_time < 2:
            if ser.in_waiting:
                response += ser.read().decode()

        if response:
            print(f"Test response: {response.strip()}")

        ser.close()
        return True

    except Exception as e:
        print(f"Upload failed: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 upload_to_pico.py <filename>")
        print("Example: python3 upload_to_pico.py pico_upload/motor_control.py")
        return

    filename = sys.argv[1]
    port = "/dev/cu.usbmodem2101"

    try:
        with open(filename, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"File not found: {filename}")
        return

    print(f"Uploading {filename} to Pico...")
    success = upload_file_to_pico(port, filename, content)

    if success:
        print("✅ Upload completed successfully!")
        print("You can now test the motor control with: python3 test_real_hardware.py")
    else:
        print("❌ Upload failed")

if __name__ == "__main__":
    main()
