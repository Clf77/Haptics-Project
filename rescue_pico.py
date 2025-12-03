import serial
import time
import sys

PORT = "/dev/cu.usbmodem11401"
BAUD = 115200

def rescue():
    port = PORT
    print(f"Waiting for {port}...")
    
    # Wait for port to appear
    while True:
        try:
            ser = serial.Serial(port, BAUD, timeout=0.1)
            ser.close() # Close immediately, just checking if it's available
            break
        except:
            time.sleep(0.1)
            
    print("Port detected! Spamming Ctrl+C...")
    
    # Try to interrupt running script
    print("Attempting to enter REPL...")
    try:
        with serial.Serial(port, BAUD, timeout=1) as ser:
            ser.write(b'\x03') # Ctrl+C
            time.sleep(0.1)
            ser.write(b'\x01') # Ctrl+A (Raw REPL)
            time.sleep(0.1)
            response = ser.read_all()
            print(f"Response: {response}")
            return True
    except Exception as e:
        print(f"Error: {e}")
        return False
        print("Failed to detect REPL.")
        ser.close()
        return False

if __name__ == "__main__":
    rescue()
