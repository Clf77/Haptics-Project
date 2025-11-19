#!/usr/bin/env python3
"""
Demo script to test communication with the running integrated system
"""

import serial
import json
import time
import sys

def demo_communication():
    """Demonstrate communication with the running system"""
    print("Haptic Lathe System Communication Demo")
    print("=" * 40)

    # Try to connect to the GUI serial port (if any)
    gui_ports = ['/dev/ttyACM0', '/dev/ttyUSB0', 'COM3', 'COM4']

    connected = False
    ser = None

    for port in gui_ports:
        try:
            ser = serial.Serial(port, 115200, timeout=1)
            print(f"✓ Connected to GUI on {port}")
            connected = True
            break
        except:
            continue

    if not connected:
        print("! No GUI serial connection (this is normal if GUI is not connected)")
        print("  The system is running in demo mode with simulated handle wheel data")
        return demo_status_only()

    try:
        print("\nSending test commands...")

        # Test mode change
        cmd1 = {"type": "mode_change", "mode": "facing", "skill_level": "beginner"}
        ser.write((json.dumps(cmd1) + "\n").encode())
        print(f"✓ Sent: {cmd1}")

        time.sleep(0.5)

        # Test parameter change
        cmd2 = {"type": "set_parameters", "spindle_rpm": 500, "feed_rate": 0.005}
        ser.write((json.dumps(cmd2) + "\n").encode())
        print(f"✓ Sent: {cmd2}")

        time.sleep(0.5)

        # Test emergency stop
        cmd3 = {"type": "emergency_stop"}
        ser.write((json.dumps(cmd3) + "\n").encode())
        print(f"✓ Sent: {cmd3}")

        print("\nListening for responses...")

        # Listen for responses
        start_time = time.time()
        while time.time() - start_time < 5:  # Listen for 5 seconds
            if ser.in_waiting:
                try:
                    line = ser.readline().decode().strip()
                    if line:
                        data = json.loads(line)
                        print(f"✓ Received: {data}")
                except:
                    pass
            time.sleep(0.1)

        ser.close()

    except KeyboardInterrupt:
        if ser:
            ser.close()
        print("\nDemo interrupted")

def demo_status_only():
    """Demo without serial connection - just show system is running"""
    print("\nSystem is running in demo mode!")
    print("Features available:")
    print("• Simulated handle wheel position (sine wave)")
    print("• GUI with training scenarios")
    print("• Safety monitoring system")
    print("• Real-time communication protocol")
    print("\nTo test with physical hardware:")
    print("1. Connect Raspberry Pi Pico with motor_control.py")
    print("2. Run: python3 integrated_lathe_controller.py")
    print("3. The system will auto-detect and use physical hardware")

if __name__ == "__main__":
    demo_communication()
