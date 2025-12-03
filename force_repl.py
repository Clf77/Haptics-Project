import serial
import time

port = "/dev/cu.usbmodem11401"
try:
    ser = serial.Serial(port, 115200, timeout=0.1)
    print(f"Connecting to {port}...")
    
    # Send Ctrl+C repeatedly
    for i in range(20):
        ser.write(b'\x03')
        time.sleep(0.1)
        response = ser.read_all()
        if response:
            print(f"Response: {response}")
            if b'>>>' in response:
                print("REPL detected!")
                break
    
    ser.close()
except Exception as e:
    print(f"Error: {e}")
