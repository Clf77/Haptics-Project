import serial
import time
import sys

def tune_motor(port="/dev/cu.usbmodem11401"):
    try:
        print(f"Connecting to {port}...")
        ser = serial.Serial(port, 115200, timeout=1)
        time.sleep(2)
        
        # Clear buffer
        ser.reset_input_buffer()
        ser.write(b"\r\n")
        time.sleep(0.1)
        
        print("\n=== Motor Tuning Tool ===")
        print("Enter raw driver commands to test resistance.")
        print("Format: <pwm_duty> <in1> <in2>")
        print("  pwm_duty: 0-65535")
        print("  in1, in2: 0 or 1")
        print("\nExamples:")
        print("  0 0 0       -> Coast (Default)")
        print("  65535 0 0   -> Enable High, Inputs Low")
        print("  65535 1 1   -> Brake (Inputs High)")
        print("  0 1 1       -> Brake (Inputs High, Enable Low)")
        print("\nType 'q' to quit.")
        
        while True:
            cmd = input("\nEnter command (e.g., 0 0 0): ").strip()
            if cmd.lower() == 'q':
                break
            
            if cmd.lower() in ['status', 'coast', 'stop']:
                command = f"{cmd}\r\n"
                ser.write(command.encode())
                print(f"Sent: {command.strip()}")
                time.sleep(0.1)
                while ser.in_waiting:
                    print(f"Response: {ser.readline().decode().strip()}")
                continue

            parts = cmd.split()
            if len(parts) != 3:
                print("Invalid format. Use: <pwm> <in1> <in2>")
                continue
                
            try:
                pwm = int(parts[0])
                in1 = int(parts[1])
                in2 = int(parts[2])
                
                command = f"raw {pwm} {in1} {in2}\r\n"
                ser.write(command.encode())
                print(f"Sent: {command.strip()}")
                
                # Read response
                time.sleep(0.1)
                while ser.in_waiting:
                    print(f"Response: {ser.readline().decode().strip()}")
                    
            except ValueError:
                print("Invalid numbers.")
                
    except serial.SerialException as e:
        print(f"Error: {e}")
    except KeyboardInterrupt:
        print("\nExiting...")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.write(b"stop\r\n")
            ser.close()

if __name__ == "__main__":
    tune_motor()
