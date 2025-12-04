import serial
import time
import sys
import os

# Configuration
import serial.tools.list_ports

# Configuration
BAUD = 115200

def find_pico_port():
    """Find the Pico's serial port automatically."""
    ports = list(serial.tools.list_ports.comports())
    print(f"Available ports: {[p.device for p in ports]}")
    
    # Look for likely candidates
    candidates = []
    for p in ports:
        # macOS Pico usually shows up as usbmodem
        if "usbmodem" in p.device:
            candidates.append(p.device)
        # Linux/Windows might show up differently, but usbmodem is key for Mac
        elif "Board in FS mode" in p.description or "MicroPython" in p.description:
            candidates.append(p.device)
            
    if not candidates:
        return None
        
    # Return the first candidate
    return candidates[0]

def write_file(ser, local_path, remote_path):
    print(f"Uploading {local_path} to {remote_path}...")
    
    with open(local_path, 'rb') as f:
        content = f.read()
    
    # Enter Raw REPL
    print("Interrupting running program...")
    ser.write(b'\x03') # Ctrl+C
    time.sleep(0.5)
    ser.write(b'\x03') # Ctrl+C again
    time.sleep(0.5)
    ser.write(b'\x03') # Ctrl+C third time
    time.sleep(0.5)
    
    ser.write(b'\x01') # Ctrl+A (Enter Raw REPL)
    time.sleep(0.5)
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
        port = find_pico_port()
        if not port:
            print("Error: No Pico found (looked for 'usbmodem')")
            print("Please check connection or update find_pico_port()")
            return

        print(f"Using port: {port}")
        
        ser = serial.Serial(port, BAUD, timeout=1)
        write_file(ser, "pico_upload/motor_control.py", "motor_control.py")
        write_file(ser, "pico_upload/main.py", "main.py")
        ser.close()
        
        # Soft reset
        print("Resetting...")
        with serial.Serial(port, BAUD, timeout=1) as ser:
            ser.write(b'\x04') # Ctrl+D
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
