"""
Integrated Haptic Lathe Controller
Combines GUI communication with motor control for handle wheel interface

Architecture:
- Processing GUI sends commands via serial to this Python bridge
- Bridge communicates with Raspberry Pi Pico motor controller
- Handle wheel position from motor encoder becomes tool position input
- GUI displays real-time position feedback

Communication Protocol:
GUI → Bridge: JSON commands over serial
Bridge → Pico: Serial commands (existing motor_control.py protocol)
Pico → Bridge: Status responses
Bridge → GUI: JSON status updates
"""

import serial
import json
import time
import threading
import queue
import math
import os
import tempfile

# Import motor control only if running on MicroPython (Pico)
try:
    from motor_control import MotorController  # Import existing motor control
    MICROPYTHON_AVAILABLE = True
except ImportError:
    MICROPYTHON_AVAILABLE = False
    MotorController = None

class LatheController:
    def __init__(self, pico_serial_port="/dev/cu.usbmodem2101"):
        self.pico_serial = None
        self.motor_controller = None
        self.pico_serial_port = pico_serial_port

        # File-based communication with GUI
        self.temp_dir = tempfile.gettempdir()
        self.gui_commands_file = os.path.join(self.temp_dir, "lathe_gui_commands.json")
        self.bridge_status_file = os.path.join(self.temp_dir, "lathe_bridge_status.json")

        # Communication queues
        self.gui_to_bridge = queue.Queue()
        self.bridge_to_gui = queue.Queue()
        self.pico_to_bridge = queue.Queue()

        # Current state
        self.current_mode = "manual"  # manual, facing, turning, boring
        self.skill_level = "beginner"  # beginner, intermediate, advanced
        self.emergency_stop = False
        self.handle_wheel_position = 0.0  # degrees
        self.tool_feed_rate = 0.0  # inches/minute
        self.spindle_rpm = 0.0
        self.target_velocity = 50.0  # RPM (default motor speed)
        self.active_axis = "Z"  # X or Z axis selection
        self.haptic_active = False
        self.haptic_force = 0.0

        # Safety limits
        self.max_velocity = 100.0  # RPM
        self.max_position_error = 10.0  # degrees
        self.heartbeat_timeout = 5.0  # seconds

        # Initialize connections
        self.initialize_connections()

    def initialize_connections(self):
        """Initialize file-based communication with GUI and serial connection to Pico"""
        # Create initial status file to signal we're running
        try:
            initial_status = {
                "bridge_running": True,
                "pico_connected": False,
                "motor_position": 0.0,
                "timestamp": time.time()
            }
            with open(self.bridge_status_file, 'w') as f:
                json.dump(initial_status, f)
            print(f"Bridge status file created: {self.bridge_status_file}")
        except Exception as e:
            print(f"Failed to create status file: {e}")

        # Try to connect to Pico motor controller
        try:
            self.pico_serial = serial.Serial(self.pico_serial_port, 115200, timeout=1)
            print(f"Connected to Pico on {self.pico_serial_port}")
        except serial.SerialException as e:
            print(f"Failed to connect to Pico: {e}")
            self.pico_serial = None

        # Initialize motor controller if running locally and MicroPython available
        if not self.pico_serial and MICROPYTHON_AVAILABLE:
            try:
                self.motor_controller = MotorController()
                print("Using local motor controller")
            except Exception as e:
                print(f"Failed to initialize local motor controller: {e}")
        elif not self.pico_serial and not MICROPYTHON_AVAILABLE:
            print("Running in desktop mode - no physical motor controller available")
            self.motor_controller = None

    def send_to_gui(self, message):
        """Send JSON message to GUI via file"""
        try:
            with open(self.bridge_status_file, 'w') as f:
                json.dump(message, f)
        except Exception as e:
            print(f"Error writing status to file: {e}")

    def read_gui_commands(self):
        """Read commands from GUI via file"""
        try:
            if os.path.exists(self.gui_commands_file):
                with open(self.gui_commands_file, 'r') as f:
                    content = f.read().strip()
                    if content:
                        # Try to parse as JSON (could be string or object)
                        data = json.loads(content)
                        print(f"📥 Received GUI command: {data}")
                        # Clear the file after reading
                        os.remove(self.gui_commands_file)
                        return data
        except json.JSONDecodeError as e:
            print(f"⚠️  JSON decode error: {e}, content: {content if 'content' in locals() else 'N/A'}")
        except Exception as e:
            print(f"⚠️  Error reading GUI commands: {e}")
        return None

    def send_to_pico(self, command):
        """Send command to Pico motor controller"""
        if self.pico_serial:
            try:
                # Clear any pending input
                self.pico_serial.reset_input_buffer()
                
                # Send command (use \r\n for MicroPython compatibility)
                cmd_bytes = (command + "\r\n").encode()
                print(f"📤 Sending to Pico: {cmd_bytes}")
                self.pico_serial.write(cmd_bytes)
                self.pico_serial.flush()
                
                # Wait for response with timeout
                import time
                time.sleep(0.1)  # Give Pico time to process
                
                # Read response
                response = ""
                start_time = time.time()
                timeout = 1.0  # 1 second timeout
                
                while time.time() - start_time < timeout:
                    if self.pico_serial.in_waiting > 0:
                        response = self.pico_serial.readline().decode().strip()
                        if response:
                            break
                    time.sleep(0.01)
                
                if not response:
                    print(f"⚠️  No response from Pico for command: {command}")
                    # Try reading all available data
                    if self.pico_serial.in_waiting > 0:
                        all_data = self.pico_serial.read(self.pico_serial.in_waiting).decode()
                        print(f"📥 Available data: {repr(all_data)}")
                
                return response if response else None
            except Exception as e:
                print(f"❌ Error communicating with Pico: {e}")
                import traceback
                traceback.print_exc()
                return None
        elif self.motor_controller:
            # Handle local motor controller commands
            return self.handle_local_command(command)

    def handle_local_command(self, command):
        """Handle commands for local motor controller"""
        parts = command.strip().split()
        if not parts:
            return "OK"

        cmd = parts[0].lower()

        if cmd == "pos" and len(parts) == 2:
            try:
                pos = float(parts[1])
                self.motor_controller.target_position = pos
                self.motor_controller.control_mode = "position"
                return f"Position set to {pos} degrees"
            except ValueError:
                return "Invalid position"

        elif cmd == "vel" and len(parts) == 2:
            try:
                vel = float(parts[1])
                self.motor_controller.target_velocity = vel
                self.motor_controller.control_mode = "velocity"
                return f"Velocity set to {vel} RPM"
            except ValueError:
                return "Invalid velocity"

        elif cmd == "stop":
            self.motor_controller.stop_motor()
            return "Motor stopped"

        elif cmd == "status":
            pos = self.motor_controller.get_position_degrees()
            vel = self.motor_controller.get_velocity_rpm()
            return ".2f"

        return "Unknown command"

    def process_gui_command(self, command):
        """Process command from GUI"""
        try:
            # Handle both string and dict inputs
            if isinstance(command, str):
                data = json.loads(command)
            elif isinstance(command, dict):
                data = command
            else:
                return
            cmd_type = data.get("type", "")

            if cmd_type == "mode_change":
                self.current_mode = data.get("mode", "manual")
                self.skill_level = data.get("skill_level", "beginner")
                print(f"Mode changed to {self.current_mode}, skill: {self.skill_level}")

            elif cmd_type == "set_parameters":
                self.spindle_rpm = data.get("spindle_rpm", 0)
                self.tool_feed_rate = data.get("feed_rate", 0)
                # Send to motor controller
                self.send_to_pico(f"vel {self.spindle_rpm}")

            elif cmd_type == "emergency_stop":
                self.emergency_stop = True
                self.send_to_pico("stop")
                print("EMERGENCY STOP ACTIVATED")

            elif cmd_type == "zero_position":
                axis = data.get("axis", "x")
                if axis == "x":
                    self.send_to_pico("zero")
                print(f"Zeroed {axis} axis")

            elif cmd_type == "reset":
                self.emergency_stop = False
                self.handle_wheel_position = 0.0
                self.send_to_pico("zero")
                print("System reset")

            elif cmd_type == "motor_control":
                self.handle_motor_control(data)

            elif cmd_type == "status_request":
                # GUI requesting status update (already handled by periodic updates)
                pass

            elif cmd_type == "axis_select":
                # Handle axis selection (X or Z)
                axis = data.get("axis", "Z")
                self.active_axis = axis
                print(f"📐 Active axis set to: {axis}")

            elif cmd_type == "haptic_feedback":
                # Handle haptic feedback commands
                self.haptic_active = data.get("active", False)
                self.haptic_force = data.get("force", 0.0)
                print(f"🖐️  Haptic feedback: {'ON' if self.haptic_active else 'OFF'}, Force: {self.haptic_force:.1f}")
                
                if self.haptic_active and self.pico_serial:
                    # Apply braking/resistance proportional to force
                    # Higher force = more braking
                    brake_percent = min(self.haptic_force / 100.0, 1.0)
                    # Send haptic command to Pico
                    self.send_to_pico(f"haptic {brake_percent}")
                elif not self.haptic_active and self.pico_serial:
                    # Disable haptic feedback
                    self.send_to_pico("haptic 0")

        except json.JSONDecodeError as e:
            print(f"Invalid JSON command: {e}")

    def handle_motor_control(self, data):
        """Handle motor control commands from GUI"""
        action = data.get("action", "")
        print(f"🎮 Processing motor control action: {action}")

        if action == "forward":
            # Start motor forward
            speed = abs(self.target_velocity) if self.target_velocity != 0 else 50
            print(f"⚙️  Sending to Pico: vel {speed}")
            response = self.send_to_pico(f"vel {speed}")
            print(f"✅ Pico response: {response}")
            print("Motor: Forward")

        elif action == "reverse":
            # Start motor reverse
            speed = -abs(self.target_velocity) if self.target_velocity != 0 else -50
            print(f"⚙️  Sending to Pico: vel {speed}")
            response = self.send_to_pico(f"vel {speed}")
            print(f"✅ Pico response: {response}")
            print("Motor: Reverse")

        elif action == "stop":
            # Stop motor
            print("⚙️  Sending to Pico: stop")
            response = self.send_to_pico("stop")
            print(f"✅ Pico response: {response}")
            print("Motor: Stop")

        elif action == "speed":
            # Set speed
            speed_value = data.get("value", 50)
            self.target_velocity = speed_value
            # Don't send to motor here - wait for direction command
            print(f"Motor speed set to: {speed_value} RPM")

        elif action == "position":
            # Manual position control
            delta = data.get("delta", 0)
            # Convert degrees to position command
            current_pos = self.handle_wheel_position
            target_pos = current_pos + delta
            print(f"⚙️  Sending to Pico: pos {target_pos}")
            response = self.send_to_pico(f"pos {target_pos}")
            print(f"✅ Pico response: {response}")
            print(f"Motor position: {current_pos:.1f}° → {target_pos:.1f}°")

    def update_status(self):
        """Update and send current status to GUI"""
        # Get current handle wheel position (from motor encoder)
        if self.pico_serial:
            # Read real encoder data from Pico
            response = self.send_to_pico("status")
            if response:
                # Parse status response from Pico
                try:
                    # Expected format: "Position: 45.67 degrees, Velocity: 0.00 RPM, Mode: velocity"
                    # Or: "Position: 45.67 degrees, Velocity: 0.00 RPM, Mode: position"
                    if "Position:" in response:
                        pos_part = response.split("Position:")[1].split(",")[0]
                        self.handle_wheel_position = float(pos_part.strip().replace("degrees", "").strip())
                        print(f"📊 Encoder position: {self.handle_wheel_position:.2f}°")
                    else:
                        print(f"⚠️  Unexpected status format: {response}")
                except (IndexError, ValueError, AttributeError) as e:
                    print(f"❌ Error parsing Pico response: {e}, response: {repr(response)}")
                    # Fall back to previous position
                    pass
            else:
                print(f"⚠️  No response from Pico status command")

        elif self.motor_controller:
            self.handle_wheel_position = self.motor_controller.get_position_degrees()

        else:
            # Demo mode: simulate handle wheel position with sine wave
            # (Only when no Pico is connected)
            self.handle_wheel_position = 30.0 * math.sin(time.time() * 0.5)
            print(f"Demo position: {self.handle_wheel_position:.2f}° (simulated)")

        # Send status update to GUI
        status = {
            "type": "status_update",
            "handle_wheel_position": self.handle_wheel_position,
            "mode": self.current_mode,
            "skill_level": self.skill_level,
            "emergency_stop": self.emergency_stop,
            "spindle_rpm": self.spindle_rpm,
            "feed_rate": self.tool_feed_rate,
            "timestamp": time.time()
        }
        self.send_to_gui(status)

    def perform_safety_checks(self):
        """Perform real-time safety checks"""
        try:
            # Check motor position limits
            if self.motor_controller:
                current_pos = self.motor_controller.get_position_degrees()
                # Add your position limits here based on your mechanical setup
                # For example: if abs(current_pos) > 360.0:  # One full rotation limit
                #     self.emergency_stop = True
                #     self.send_to_pico("stop")
                #     print("Position limit exceeded - emergency stop")

            # Check motor velocity limits
            if self.motor_controller:
                current_vel = abs(self.motor_controller.get_velocity_rpm())
                if current_vel > self.max_velocity:
                    print(f"Velocity limit exceeded: {current_vel} RPM")
                    self.send_to_pico("stop")
                    # Don't set emergency_stop for velocity limits, just stop

            # Check for motor stall (if velocity is 0 but we're commanding movement)
            # This would require tracking commanded vs actual velocity

        except Exception as e:
            print(f"Safety check error: {e}")

    def run_control_loop(self):
        """Main control loop with safety monitoring"""
        last_status_time = 0
        status_interval = 0.1  # 10Hz updates
        last_safety_check = 0
        safety_check_interval = 0.05  # 20Hz safety checks
        last_heartbeat_check = 0
        heartbeat_check_interval = 1.0  # 1Hz heartbeat

        # Safety state tracking
        consecutive_errors = 0
        max_consecutive_errors = 10
        last_gui_heartbeat = time.time()
        gui_connected = False

        while not self.emergency_stop:
            current_time = time.time()

            # Check for GUI commands via file
            gui_command = self.read_gui_commands()
            if gui_command:
                try:
                    if isinstance(gui_command, str):
                        # Single command
                        self.process_gui_command(gui_command)
                    else:
                        # Multiple commands or single command as dict
                        self.process_gui_command(gui_command)
                    last_gui_heartbeat = current_time
                    gui_connected = True
                    consecutive_errors = 0
                except Exception as e:
                    # Don't count JSON errors as consecutive errors - GUI might not be sending commands
                    print(f"Error processing GUI command: {e}")
                    # Only increment errors if it's a real communication problem, not missing commands
                    # consecutive_errors += 1  # DISABLED - don't crash on JSON errors

            # Safety checks
            if current_time - last_safety_check > safety_check_interval:
                self.perform_safety_checks()
                last_safety_check = current_time

            # Heartbeat monitoring
            if current_time - last_heartbeat_check > heartbeat_check_interval:
                if gui_connected and current_time - last_gui_heartbeat > self.heartbeat_timeout:
                    print("GUI heartbeat timeout - activating safety stop")
                    self.emergency_stop = True
                    self.send_to_pico("stop")
                last_heartbeat_check = current_time

            # Emergency stop on too many consecutive errors
            if consecutive_errors > max_consecutive_errors:
                print("Too many consecutive communication errors - emergency stop")
                self.emergency_stop = True
                self.send_to_pico("stop")

            # Send status updates
            if current_time - last_status_time > status_interval:
                self.update_status()
                last_status_time = current_time

            # Run motor control loop if using local controller
            if self.motor_controller and not self.emergency_stop:
                try:
                    if self.motor_controller.control_mode == "position":
                        self.motor_controller.position_control()
                    elif self.motor_controller.control_mode == "velocity":
                        self.motor_controller.velocity_control()
                except Exception as e:
                    print(f"Motor control error: {e}")
                    self.emergency_stop = True

            time.sleep(0.01)  # 100Hz loop

    def shutdown(self):
        """Clean shutdown"""
        if self.pico_serial:
            self.send_to_pico("stop")
            self.pico_serial.close()

        # Clean up communication files
        try:
            if os.path.exists(self.bridge_status_file):
                os.remove(self.bridge_status_file)
            if os.path.exists(self.gui_commands_file):
                os.remove(self.gui_commands_file)
        except Exception as e:
            print(f"Error cleaning up files: {e}")

        if self.motor_controller:
            self.motor_controller.stop_motor()

        print("Lathe controller shut down")

def main():
    print("Haptic Lathe Controller Starting...")

    # Use file-based communication for GUI and try different serial ports for Pico
    pico_ports = ["/dev/cu.usbmodem2101", "/dev/tty.usbmodem2101", "/dev/ttyACM1", "/dev/ttyUSB1", "COM5", "COM6"]

    controller = None

    # Try to create controller with file-based GUI communication
    for pico_port in pico_ports:
        try:
            controller = LatheController(pico_serial_port=pico_port)
            # Controller will use file-based communication for GUI and try to connect to Pico
            break
        except Exception as e:
            print(f"Failed to initialize with {pico_port}: {e}")
            continue

    if not controller:
        print("Failed to initialize controller. Trying without Pico connection.")
        try:
            controller = LatheController(pico_serial_port="/dev/ttyACM1")
        except Exception as e:
            print(f"Failed to initialize basic controller: {e}")
            return 1

    try:
        print("Controller initialized. Starting control loop...")
        controller.run_control_loop()
    except KeyboardInterrupt:
        print("Interrupted by user")
    finally:
        if controller:
            controller.shutdown()

if __name__ == "__main__":
    main()
