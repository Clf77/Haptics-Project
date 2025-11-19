#!/usr/bin/env python3
"""
Debug script to test Pico serial communication
"""

import serial
import time

def test_pico_communication():
    pico_port = "/dev/cu.usbmodem2101"

    try:
        ser = serial.Serial(pico_port, 115200, timeout=2)
        print(f"Connected to {pico_port}")

        # Test basic communication
        commands = ["status", "vel 10", "stop", "help", "pos 30"]

        for cmd in commands:
            print(f"\nSending: {cmd}")

            # Clear any pending data
            ser.reset_input_buffer()

            # Send command
            ser.write((cmd + "\n").encode())
            time.sleep(0.2)

            # Read response
            response = ""
            start_time = time.time()

            while time.time() - start_time < 2:
                if ser.in_waiting:
                    try:
                        char = ser.read().decode()
                        if char == '\n':
                            break
                        response += char
                    except:
                        break

            if response:
                print(f"Response: '{response}'")
            else:
                print("No response")

            time.sleep(0.5)

        ser.close()
        print("\nConnection closed")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_pico_communication()
