import serial
import time
import sys
import os

# Configuration
PORT = '/dev/cu.usbmodem14334101'
BAUD = 115200

def write_file(ser, local_path, remote_path):
    print(f"Uploading {local_path} to {remote_path}...")
    
    with open(local_path, 'rb') as f:
        content = f.read()
    
    # Enter Raw REPL
    ser.write(b'\x03') # Ctrl+C
    time.sleep(0.1)
    ser.write(b'\x01') # Ctrl+A
    time.sleep(0.1)
    if not b'raw REPL' in ser.read_all():
        print("Failed to enter raw REPL")
        return False

    # Open file
    cmd = f"f = open('{remote_path}', 'wb')".encode('utf-8')
    ser.write(cmd + b'\x04') # Execute
    time.sleep(0.1)
    
    # Write chunks
    chunk_size = 64
    for i in range(0, len(content), chunk_size):
        chunk = content[i:i+chunk_size]
        cmd = f"f.write({chunk})".encode('utf-8')
        ser.write(cmd + b'\x04')
        # Wait for OK
        start = time.time()
        while time.time() - start < 1.0:
            if b'OK' in ser.read_all():
                break
            time.sleep(0.01)
        print(f"\rProgress: {i}/{len(content)} bytes", end="")
        
    print("\nClosing file...")
    ser.write(b"f.close()" + b'\x04')
    time.sleep(0.1)
    ser.read_all()
    
    # Exit Raw REPL
    ser.write(b'\x02') # Ctrl+B
    print("Done.")
    return True

def main():
    try:
        ser = serial.Serial(PORT, BAUD, timeout=1)
        write_file(ser, "pico_upload/motor_control.py", "motor_control.py")
        write_file(ser, "pico_upload/main.py", "main.py")
        ser.close()
        
        # Soft reset
        print("Resetting...")
        with serial.Serial(PORT, BAUD, timeout=1) as ser:
            ser.write(b'\x04') # Ctrl+D
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
