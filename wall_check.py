import serial
import time
import sys

def test_virtual_wall(port="/dev/cu.usbmodem11401"):
    try:
        print(f"Connecting to {port}...")
        ser = serial.Serial(port, 115200, timeout=1)
        time.sleep(2)  # Wait for connection to settle
        
        # Clear buffer
        ser.reset_input_buffer()
        
        # Send a few newlines to clear any partial commands
        ser.write(b"\r\n\r\n")
        time.sleep(0.5)
        ser.reset_input_buffer()
        
        # Send Soft Reset (Ctrl+D) to ensure main.py starts
        print("Sending Soft Reset to start main.py...")
        ser.write(b'\x04')
        time.sleep(2.0)  # Wait for reboot
        ser.reset_input_buffer()
        
        print("Sending command: stop")
        ser.write(b"stop\r\n")
        time.sleep(0.5)
        
        print("Sending command: spring_wall 20 1")
        cmd = "spring_wall 20 1\r\n"
        ser.write(cmd.encode())
        ser.flush()
        
        # Read response with a timeout loop
        print("Waiting for response...")
        start_time = time.time()
        while time.time() - start_time < 2.0:
            if ser.in_waiting:
                line = ser.readline().decode().strip()
                print(f"Response: {line}")
            time.sleep(0.05)
            
        print("\nVirtual wall engaged with 20N force.")
        print("Please turn the handle to test the resistance.")
        print("Press Ctrl+C to stop and release the wall.")
        
        while True:
            # Keep connection open and monitor status
            ser.write(b"status\r\n")
            time.sleep(0.5)
            while ser.in_waiting:
                line = ser.readline().decode().strip()
                if line:
                    print(f"Status: {line}")
            time.sleep(0.5)
            
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
    except KeyboardInterrupt:
        print("\nStopping...")
        if 'ser' in locals() and ser.is_open:
            ser.write(b"spring_wall 0 0\r\n")
            ser.write(b"stop\r\n")
            ser.close()
        print("Wall released.")

if __name__ == "__main__":
    test_virtual_wall()
