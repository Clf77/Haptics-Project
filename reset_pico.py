import serial
import time

port = "/dev/cu.usbmodem11401"
try:
    ser = serial.Serial(port, 115200, timeout=1)
    print(f"Sending soft reset to {port}...")
    ser.write(b'\x03') # Ctrl+C to interrupt
    time.sleep(0.1)
    ser.write(b'\x04') # Ctrl+D to soft reset
    time.sleep(1.0)
    print("Done.")
    ser.close()
except Exception as e:
    print(f"Error: {e}")
