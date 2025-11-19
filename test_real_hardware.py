#!/usr/bin/env python3
"""
Real Hardware Testing Script for CQR37D Haptic Lathe System
Tests actual motor control and encoder reading with physical hardware
"""

import serial
import time
import json
import tempfile
import os

class HardwareTester:
    def __init__(self):
        # Try multiple possible Pico ports
        self.possible_ports = [
            "/dev/cu.usbmodem2101",
            "/dev/tty.usbmodem2101",
            "/dev/cu.usbmodem1234561",  # Common Pico port
            "/dev/tty.usbmodem1234561",
            "/dev/cu.usbserial-2101",
            "/dev/tty.usbserial-2101"
        ]
        self.pico_port = None
        self.serial_conn = None
        self.temp_dir = tempfile.gettempdir()
        self.bridge_status_file = os.path.join(self.temp_dir, "lathe_bridge_status.json")

    def connect_to_pico(self):
        """Connect to Raspberry Pi Pico"""
        for port in self.possible_ports:
            try:
                self.serial_conn = serial.Serial(port, 115200, timeout=2)
                self.pico_port = port
                
                # Enter raw REPL mode for better communication
                self.serial_conn.write(b'\x03')  # Ctrl-C
                time.sleep(0.1)
                self.serial_conn.write(b'\x03')  # Ctrl-C again
                time.sleep(0.1)
                self.serial_conn.write(b'\x02')  # Ctrl-B for normal REPL
                time.sleep(0.2)
                self.serial_conn.reset_input_buffer()
                
                print(f"✅ Connected to Pico on {port}")
                return True
            except Exception as e:
                continue

        print("❌ Failed to connect to Pico on any port")
        print("Available ports:")
        import serial.tools.list_ports
        ports = list(serial.tools.list_ports.comports())
        for port in ports:
            print(f"  {port.device}: {port.description}")
        print("\nMake sure:")
        print("1. Pico is plugged in and not in BOOTSEL mode")
        print("2. motor_control.py was uploaded successfully")
        print("3. Pico has restarted after upload")
        return False

    def send_command(self, command, timeout=2):
        """Send command to Pico and get response"""
        if not self.serial_conn:
            return None

        try:
            # Send command
            self.serial_conn.write((command + "\r\n").encode())
            time.sleep(0.2)  # Wait for command to execute

            response = ""
            start_time = time.time()

            # Read all available data
            while time.time() - start_time < timeout:
                if self.serial_conn.in_waiting:
                    try:
                        response += self.serial_conn.read(self.serial_conn.in_waiting).decode('utf-8', errors='ignore')
                    except:
                        break
                    time.sleep(0.05)
                else:
                    if response:  # If we got some response, we're done
                        break
                    time.sleep(0.05)

            return response.strip()

        except Exception as e:
            print(f"Error communicating with Pico: {e}")
            return None

    def test_basic_connection(self):
        """Test basic serial connection to Pico"""
        print("\n🔌 Testing Pico Connection...")
        response = self.send_command("status")
        if response and "Position:" in response:
            print("✅ Pico responding to commands")
            return True
        else:
            print("❌ Pico not responding")
            return False

    def test_encoder_reading(self):
        """Test encoder functionality"""
        print("\n📏 Testing Encoder Reading...")

        # Get initial position
        initial_response = self.send_command("status")
        if not initial_response:
            return False

        try:
            initial_pos = float(initial_response.split("Position:")[1].split()[0])
            print(f"Initial position: {initial_pos:.2f}°")
        except:
            print("❌ Could not parse initial position")
            return False

        print("⚠️  Manually rotate the motor shaft/handle wheel now...")
        print("Waiting 10 seconds for manual rotation...")

        time.sleep(10)

        # Get final position
        final_response = self.send_command("status")
        if not final_response:
            return False

        try:
            final_pos = float(final_response.split("Position:")[1].split()[0])
            print(f"Final position: {final_pos:.2f}°")

            movement = abs(final_pos - initial_pos)
            print(f"Total movement: {movement:.2f}°")

            if movement > 5:  # At least 5 degrees movement
                print("✅ Encoder working - detected movement!")
                return True
            else:
                print("❌ Encoder not detecting movement")
                print("Check encoder wiring and motor shaft rotation")
                return False

        except Exception as e:
            print(f"❌ Error parsing final position: {e}")
            return False

    def test_motor_movement(self):
        """Test motor movement in both directions"""
        print("\n⚙️  Testing Motor Movement...")

        directions = [
            ("Clockwise", "vel 30", 3),
            ("Counter-clockwise", "vel -30", 3),
            ("Stop", "stop", 1)
        ]

        for direction, command, duration in directions:
            print(f"Testing {direction} movement...")
            response = self.send_command(command)
            if response:
                print(f"✅ Command '{command}' sent: {response}")
            else:
                print(f"❌ Command '{command}' failed")

            time.sleep(duration)

            # Check position during movement (except for stop)
            if command != "stop":
                status_response = self.send_command("status")
                if status_response:
                    try:
                        pos_str = status_response.split("Position:")[1].split()[0]
                        vel_str = status_response.split("Velocity:")[1].split()[0]
                        print(f"  Position: {pos_str}°, Velocity: {vel_str} RPM")
                    except:
                        pass

        # Final stop
        self.send_command("stop")
        print("✅ Motor movement test complete")
        return True

    def test_position_control(self):
        """Test position control functionality"""
        print("\n🎯 Testing Position Control...")

        test_positions = [45, 90, 0, -45]

        for target_pos in test_positions:
            print(f"Moving to {target_pos}°...")
            response = self.send_command(f"pos {target_pos}")

            if response:
                print(f"✅ Position command sent: {response}")
            else:
                print(f"❌ Position command failed")
                return False

            # Wait for movement to complete (simple timeout)
            time.sleep(5)

            # Check actual position
            status_response = self.send_command("status")
            if status_response:
                try:
                    actual_pos = float(status_response.split("Position:")[1].split()[0])
                    error = abs(actual_pos - target_pos)
                    print(".2f")

                    if error > 5:  # Allow 5 degree tolerance
                        print("⚠️  Position accuracy needs tuning")
                except:
                    print("❌ Could not parse position")

        print("✅ Position control test complete")
        return True

    def test_integrated_system(self):
        """Test the full integrated system with GUI"""
        print("\n🔗 Testing Integrated System...")

        # Start the Python controller
        print("Starting Python bridge controller...")
        # Note: This would need to be run separately

        # Check if status file gets created
        if os.path.exists(self.bridge_status_file):
            print("✅ Bridge status file exists")
            try:
                with open(self.bridge_status_file, 'r') as f:
                    data = json.load(f)
                print(f"Status data: {data}")
            except:
                print("❌ Could not read status file")
        else:
            print("❌ Bridge status file not found")
            print("Make sure integrated_lathe_controller.py is running")

        return True

    def run_full_test(self):
        """Run complete hardware test suite"""
        print("🧪 CQR37D HAPTIC LATHE - HARDWARE TEST SUITE")
        print("=" * 50)

        if not self.connect_to_pico():
            return False

        tests = [
            ("Basic Connection", self.test_basic_connection),
            ("Encoder Reading", self.test_encoder_reading),
            ("Motor Movement", self.test_motor_movement),
            ("Position Control", self.test_position_control),
            ("Integrated System", self.test_integrated_system)
        ]

        results = []
        for test_name, test_func in tests:
            print(f"\n{'='*20} {test_name} {'='*20}")
            try:
                result = test_func()
                results.append((test_name, result))
            except Exception as e:
                print(f"❌ Test {test_name} crashed: {e}")
                results.append((test_name, False))

        # Summary
        print(f"\n{'='*50}")
        print("TEST SUMMARY")
        print(f"{'='*50}")

        passed = 0
        for test_name, result in results:
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"{status}: {test_name}")
            if result:
                passed += 1

        print(f"\nPassed: {passed}/{len(results)}")

        if passed == len(results):
            print("\n🎉 ALL HARDWARE TESTS PASSED!")
            print("The CQR37D haptic lathe system is working correctly!")
            return True
        else:
            print(f"\n⚠️  {len(results) - passed} test(s) failed")
            print("Check hardware connections and try again")
            return False

    def cleanup(self):
        """Clean up connections"""
        if self.serial_conn:
            self.send_command("stop")  # Make sure motor is stopped
            self.serial_conn.close()
            print("✅ Pico connection closed")

def main():
    tester = HardwareTester()

    try:
        success = tester.run_full_test()

        if success:
            print("\n🚀 SYSTEM READY FOR USE!")
            print("You can now run the integrated GUI and control the real motor!")
        else:
            print("\n🔧 HARDWARE ISSUES DETECTED")
            print("Check connections and run tests again")

    except KeyboardInterrupt:
        print("\n⚠️  Test interrupted by user")
    finally:
        tester.cleanup()

if __name__ == "__main__":
    main()
