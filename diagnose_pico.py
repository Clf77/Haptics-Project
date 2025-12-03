import serial
import time
import sys

PORT = "/dev/cu.usbmodem11401"
BAUD = 115200

def diagnose():
    print(f"Diagnosing Pico on {PORT}...")
    
    try:
        ser = serial.Serial(PORT, BAUD, timeout=1)
        print("✓ Port opened successfully")
        
        # Clear buffer
        ser.reset_input_buffer()
        
        # Send status command
        print("Sending 'status' command...")
        ser.write(b"status\n")
        time.sleep(0.1)
        
        response = ser.read_all().decode('utf-8', errors='replace')
        if response.strip():
            print(f"✓ Received response:\n{response}")
        else:
            print("✗ No response received")
            
        # Send help command
        print("Sending 'help' command...")
        ser.write(b"help\n")
        time.sleep(0.1)
        
        response = ser.read_all().decode('utf-8', errors='replace')
        if response.strip():
            print(f"✓ Received response:\n{response}")
        else:
            print("✗ No response received")

        ser.close()
        
    except Exception as e:
        print(f"✗ Error: {e}")

if __name__ == "__main__":
    diagnose()
