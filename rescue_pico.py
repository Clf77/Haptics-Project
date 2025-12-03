import serial
import time
import sys

def rescue():
    port = "/dev/cu.usbmodem11401"
    print(f"Waiting for {port}...")
    
    # Wait for port to appear
    while True:
        try:
            ser = serial.Serial(port, 115200, timeout=0.1)
            break
        except:
            time.sleep(0.1)
            
    print("Port detected! Spamming Ctrl+C...")
    
    # Spam Ctrl+C to interrupt main.py
    start_time = time.time()
    while time.time() - start_time < 5.0:
        ser.write(b'\x03')
        time.sleep(0.01)
        
    print("Attempting to enter REPL...")
    ser.write(b'\r\n')
    time.sleep(0.1)
    resp = ser.read_all()
    print(f"Response: {resp}")
    
    if b'>>>' in resp:
        print("SUCCESS: REPL detected.")
        # Now we can try to overwrite main.py with a safe version
        # We'll just write a dummy main.py directly via REPL to be safe
        print("Disabling main.py...")
        ser.write(b"f = open('main.py', 'w')\r\nf.write('print(\"Safe mode\")\\n')\r\nf.close()\r\n")
        time.sleep(1.0)
        print("Safe main.py written.")
        ser.close()
        return True
    else:
        print("Failed to detect REPL.")
        ser.close()
        return False

if __name__ == "__main__":
    rescue()
