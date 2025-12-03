import serial
import time

PORT = "/dev/cu.usbmodem11401"
BAUD = 115200

def soft_reset():
    print(f"Sending soft reset to {PORT}...")
    try:
        with serial.Serial(PORT, BAUD, timeout=1) as ser:
            ser.write(b'\x04')  # Ctrl+D to soft reset
        print("Done.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    soft_reset()
