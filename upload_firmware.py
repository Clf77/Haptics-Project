import serial
import time
import os

# Configuration
PICO_PORT = "/dev/cu.usbmodem14334101"  # Adjust if needed
BAUD_RATE = 115200
FILES_TO_UPLOAD = [
    ("pico_upload/motor_control.py", "motor_control.py"),
    ("pico_upload/main.py", "main.py")
]

def send_file(ser, local_path, remote_name):
    print(f"Uploading {local_path} to {remote_name}...")
    
    with open(local_path, "rb") as f:
        content = f.read()
    
    # Enter raw REPL
    ser.write(b'\x01') # Ctrl+A
    time.sleep(0.1)
    
    # Command to open file and write content
    # We'll write in chunks to avoid buffer overflow
    
    # First, create/truncate the file
    cmd = f"f = open('{remote_name}', 'wb')\nw = f.write\n"
    ser.write(cmd.encode())
    time.sleep(0.1)
    
    # Write content in chunks
    CHUNK_SIZE = 256
    total_bytes = len(content)
    sent_bytes = 0
    
    for i in range(0, total_bytes, CHUNK_SIZE):
        chunk = content[i:i+CHUNK_SIZE]
        # We send the chunk as a python bytes literal
        # repr(chunk) gives us b'...' string
        cmd = f"w({repr(chunk)})\n"
        ser.write(cmd.encode())
        
        # Wait a bit for the write to happen
        time.sleep(0.05)
        
        sent_bytes += len(chunk)
        print(f"  Sent {sent_bytes}/{total_bytes} bytes", end='\r')
        
        # Check for flow control (simple)
        if ser.in_waiting > 0:
            resp = ser.read(ser.in_waiting)
            # print(f"Resp: {resp}")

    print(f"\n  Finished sending {remote_name}")
    
    # Close file
    ser.write(b"f.close()\n")
    time.sleep(0.5)
    
    # Verify existence (optional, but good)
    # ser.write(f"import os; print('{remote_name}' in os.listdir())\n".encode())
    # time.sleep(0.1)
    # print(ser.read_all().decode())

def main():
    try:
        ser = serial.Serial(PICO_PORT, BAUD_RATE, timeout=1)
    except Exception as e:
        print(f"Could not open port {PICO_PORT}: {e}")
        # Try to find port automatically
        import glob
        ports = glob.glob("/dev/cu.usbmodem*")
        if ports:
            print(f"Found ports: {ports}, trying {ports[0]}")
            ser = serial.Serial(ports[0], BAUD_RATE, timeout=1)
        else:
            print("No Pico port found.")
            return

    print(f"Connected to {ser.port}")
    
    # Interrupt any running program
    ser.write(b'\x03') # Ctrl+C
    time.sleep(0.1)
    ser.write(b'\x03') # Ctrl+C
    time.sleep(0.1)
    
    # Enter Raw REPL
    ser.write(b'\x01') # Ctrl+A
    time.sleep(0.5)
    resp = ser.read_all()
    print(f"Entered Raw REPL: {resp}")
    
    # Upload files
    for local, remote in FILES_TO_UPLOAD:
        send_file(ser, local, remote)
        
    # Soft reset to run main.py
    print("Resetting Pico...")
    ser.write(b'\x04') # Ctrl+D
    time.sleep(2)
    print("Done!")
    ser.close()

if __name__ == "__main__":
    main()
