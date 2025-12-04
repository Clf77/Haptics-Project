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

import socket
import select

class LatheController:
    def __init__(self, pico_serial_port="/dev/cu.usbmodem2101"):
        self.pico_serial = None
        self.motor_controller = None
        self.pico_serial_port = pico_serial_port

        # TCP Socket Server for GUI communication
        self.server_socket = None
        self.client_socket = None
        self.host = '127.0.0.1'
        self.port = 5005
        
        # Communication queues
        self.gui_to_bridge = queue.Queue()
        self.bridge_to_gui = queue.Queue()
        self.pico_to_bridge = queue.Queue()

        # Current state
        self.current_mode = "manual"
        self.skill_level = "beginner"
        self.emergency_stop = False
        self.handle_wheel_position = 0.0
        self.tool_feed_rate = 0.0
        self.spindle_rpm = 0.0
        self.target_velocity = 50.0
        self.active_axis = "Z"
        self.haptic_active = False
        self.haptic_force = 0.0

        # Safety limits
        self.max_velocity = 100.0
        self.max_position_error = 10.0
        self.heartbeat_timeout = 5.0

        # Initialize connections
        self.initialize_connections()

        # Try to connect to Pico motor controller
        try:
            self.pico_serial = serial.Serial(self.pico_serial_port, 921600, timeout=0.1) # High speed baud
            print(f"Connected to Pico on {self.pico_serial_port}")
        except serial.SerialException as e:
            print(f"Failed to connect to Pico: {e}")
            self.pico_serial = None

    def initialize_connections(self):
        """Initialize TCP server and serial connection to Pico"""
        # Start TCP Server
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1) # Disable Nagle's algorithm
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(1)
            self.server_socket.setblocking(False)
            print(f"TCP Server listening on {self.host}:{self.port}")
        except Exception as e:
            print(f"Failed to start TCP server: {e}")

        # ... (rest of method)

    def run_control_loop(self):
        """Main control loop with safety monitoring"""
        last_status_time = 0
        status_interval = 0.016  # ~60Hz updates to GUI (match screen refresh)
        
        last_pico_status_req = 0
        pico_status_interval = 0.01  # 100Hz Pico polling (balanced load)
        
        last_safety_check = 0
        safety_check_interval = 0.05  # 20Hz safety checks
        
        last_heartbeat_check = 0
        heartbeat_check_interval = 1.0  # 1Hz heartbeat

        # Initialize motor controller if running locally
        if not self.pico_serial and MICROPYTHON_AVAILABLE:
            try:
                self.motor_controller = MotorController()
                print("Using local motor controller")
            except Exception as e:
                print(f"Failed to initialize local controller: {e}")

    def accept_gui_connection(self):
        """Check for new GUI client connections"""
        if self.server_socket:
            try:
                readable, _, _ = select.select([self.server_socket], [], [], 0)
                if readable:
                    client, addr = self.server_socket.accept()
                    client.setblocking(False)
                    self.client_socket = client
                    print(f"GUI Connected from {addr}")
            except Exception as e:
                print(f"Error accepting connection: {e}")

    def read_gui_commands(self):
        """Read commands from TCP socket"""
        if not self.client_socket:
            self.accept_gui_connection()
            return None

        try:
            # Check if data is available
            readable, _, _ = select.select([self.client_socket], [], [], 0)
            if readable:
                data = self.client_socket.recv(4096)
                if not data:
                    print("GUI Disconnected")
                    self.client_socket.close()
                    self.client_socket = None
                    return None
                
                # Split by newline in case multiple commands arrived
                commands = data.decode().strip().split('\n')
                last_valid_cmd = None
                
                for cmd_str in commands:
                    if not cmd_str: continue
                    
                    # Handle "FORCE:" command (High-speed haptic update)
                    if cmd_str.startswith("FORCE:"):
                        try:
                            # Format: FORCE:Fx,Fz,Freq
                            parts = cmd_str.split(":")[1].split(",")
                            if len(parts) >= 3:
                                fx = float(parts[0])
                                fz = float(parts[1])
                                freq = float(parts[2])
                                
                                # Construct a command dict compatible with process_gui_command
                                # But we might want to process it directly here for speed?
                                # Let's create a special dict
                                last_valid_cmd = {
                                    "type": "haptic_vector",
                                    "fx": fx,
                                    "fz": fz,
                                    "freq": freq
                                }
                        except ValueError:
                            print(f"Invalid FORCE command: {cmd_str}")
                            pass
                    else:
                        try:
                            cmd = json.loads(cmd_str)
                            last_valid_cmd = cmd
                        except json.JSONDecodeError:
                            pass
                
                return last_valid_cmd
                
        except Exception as e:
            print(f"Socket receive error: {e}")
            self.client_socket = None
            return None
            
        return None

    def send_to_pico(self, command):
        """Send command to Pico motor controller"""
        if self.pico_serial:
            try:
                # Send command
                cmd_bytes = (command + "\r\n").encode()
                self.pico_serial.write(cmd_bytes)
                
                # Don't wait for response here to avoid blocking the high-speed loop
                # We read responses in the main loop
                
            except Exception as e:
                print(f"❌ Error communicating with Pico: {e}")
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

        elif cmd == "spring_wall" and len(parts) >= 2:
            try:
                force_val = float(parts[1])
                wall_flag = float(parts[2]) if len(parts) >= 3 else 1.0
                self.motor_controller.set_spring_wall(force_val, wall_flag)
                return f"Virtual wall {'engaged' if force_val > 0 and wall_flag != 0 else 'released'}"
            except ValueError:
                return "Invalid spring_wall values"

        elif cmd == "status":
            pos = self.motor_controller.get_position_degrees()
            vel = self.motor_controller.get_velocity_rpm()
            status = f"Position: {pos:.2f} degrees, Velocity: {vel:.2f} RPM, Mode: {self.motor_controller.control_mode}"
            if getattr(self.motor_controller, "wall_engaged", False):
                status += f", Wall @ {self.motor_controller.wall_contact_position_deg:.2f}°"
            return status

        return "Unknown command"

    def process_gui_command(self, data):
        """Process parsed JSON command from GUI"""
        try:
            cmd_type = data.get("type")
            
            if cmd_type == "status_request":
                # Trigger immediate update for low latency
                self.update_status()
                
            elif cmd_type == "mode_change":
                self.current_mode = data.get("mode", "manual")
                self.skill_level = data.get("skill_level", "beginner")
                print(f"Mode changed to: {self.current_mode} ({self.skill_level})")
                
            elif cmd_type == "emergency_stop":
                self.emergency_stop = True
                self.send_to_pico("stop")
                print("🚨 EMERGENCY STOP ACTIVATED")
                
            elif cmd_type == "motor_control":
                action = data.get("action")
                if action == "forward":
                    self.send_to_pico(f"vel {self.target_velocity}")
                elif action == "reverse":
                    self.send_to_pico(f"vel {-self.target_velocity}")
                elif action == "stop":
                    print("⚙️  Sending to Pico: stop")
                    response = self.send_to_pico("stop")
                    print(f"✅ Pico response: {response}")
                    print("Motor: Stop")
                elif action == "speed":
                    speed_value = float(data.get("value", 50.0))
                    self.target_velocity = speed_value
                    print(f"Motor speed set to: {speed_value} RPM")
                elif action == "position":
                    delta = float(data.get("delta", 0.0))
                    current_pos = self.handle_wheel_position
                    target_pos = current_pos + delta
                    print(f"⚙️  Sending to Pico: pos {target_pos}")
                    response = self.send_to_pico(f"pos {target_pos}")
                    print(f"✅ Pico response: {response}")
                    print(f"Motor position: {current_pos:.1f}° → {target_pos:.1f}°")
                    
            elif cmd_type == "zero_position":
                axis = data.get("axis")
                print(f"Zeroing {axis} axis")
                # We don't zero the motor for this, just the GUI offset
                
            elif cmd_type == "axis_select":
                self.active_axis = data.get("axis", "Z")
                print(f"Active axis: {self.active_axis}")
                
            elif cmd_type == "haptic_feedback":
                self.haptic_active = data.get("active", False)
                self.haptic_force = data.get("force", 0.0)
                self.vib_freq = data.get("freq", 10.0)
                self.yield_force = data.get("yield", 50.0) # Default to rigid
                
                if self.haptic_active and self.pico_serial:
                    physical_force = (self.haptic_force / 100.0) * 50.0
                    
                    # FIX: Handle negative forces correctly
                    # wall_active needs to be non-zero to engage
                    # Use sign of force as direction hint (1 or -1) * 2 to be safe > 1.0
                    if abs(physical_force) > 0.1:
                        wall_dir = 1 if physical_force >= 0 else -1
                        wall_active = wall_dir * 2 
                    else:
                        wall_active = 0
                        
                    # Send absolute force magnitude, direction is handled by wall_active sign
                    self.send_to_pico(f"spring_wall {abs(physical_force):.2f} {wall_active} {self.vib_freq:.1f} {self.yield_force:.1f}")
                    print(f"🧱 Wall: {physical_force:.1f}N, Dir: {wall_active}, Freq: {self.vib_freq:.1f}Hz")
                elif not self.haptic_active and self.pico_serial:
                    self.send_to_pico("spring_wall 0 0")
                    
            elif cmd_type == "haptic_vector":
                # New high-speed vector format
                fx = data.get("fx", 0.0)
                fz = data.get("fz", 0.0)
                freq = data.get("freq", 0.0)
                
                # Determine which axis is active/dominant or combine them?
                # Currently Pico only supports 1D "spring_wall".
                # We need to map Fx/Fz to the single motor axis based on active mode.
                # But the GUI already sends 0 for the inactive axis.
                
                total_force = fx if abs(fx) > abs(fz) else fz
                
                # Map to Pico direction
                # Force > 0 -> Wall Dir 1 (Push Left/CCW)
                # Force < 0 -> Wall Dir -1 (Push Right/CW)
                direction = 1 if total_force >= 0 else -1
                force_mag = abs(total_force)
                
                # Send to Pico
                # Use direction * 2 to ensure abs(flag) > 1.0, forcing Pico to use our direction hint
                wall_flag = direction * 2
                
                self.send_to_pico(f"spring_wall {force_mag:.2f} {wall_flag} {freq:.1f}")

        except json.JSONDecodeError as e:
            print(f"Error processing GUI command: {e}")
        except Exception as e:
            print(f"Error processing GUI command: {e}")

    def update_status(self):
        """Send status update to GUI via TCP"""
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
        
        if self.client_socket:
            try:
                msg = json.dumps(status) + "\n"
                self.client_socket.sendall(msg.encode())
            except Exception as e:
                print(f"Socket send error: {e}")
                self.client_socket = None

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

    def read_pico_response(self):
        """Non-blocking read from Pico"""
        updated = False
        if self.pico_serial and self.pico_serial.in_waiting > 0:
            try:
                line = self.pico_serial.readline().decode().strip()
                if line:
                    # Parse status updates
                    if "Position:" in line:
                        # Parse: Position: -135.94 degrees, Velocity: ...
                        parts = line.split(',')
                        for part in parts:
                            if "Position:" in part:
                                try:
                                    pos_str = part.split(':')[1].replace('degrees', '').strip()
                                    new_pos = float(pos_str)
                                    if new_pos != self.handle_wheel_position:
                                        self.handle_wheel_position = new_pos
                                        updated = True
                                except:
                                    pass
                    return updated
            except Exception:
                pass
        return False

    def run_control_loop(self):
        """Main control loop with safety monitoring"""
        last_status_time = 0
        status_interval = 0.033  # Keep as fallback heartbeat
        
        last_pico_status_req = 0
        pico_status_interval = 0.01  # 100Hz Pico polling
        
        last_safety_check = 0
        safety_check_interval = 0.05  # 20Hz safety checks
        
        last_heartbeat_check = 0
        heartbeat_check_interval = 1.0  # 1Hz heartbeat

        # Safety state tracking
        consecutive_errors = 0
        max_consecutive_errors = 10
        last_gui_heartbeat = time.time()
        gui_connected = False

        print("Starting control loop (500Hz)...")

        while not self.emergency_stop:
            current_time = time.time()

            # 1. Read GUI Commands
            gui_command = self.read_gui_commands()
            if gui_command:
                try:
                    if isinstance(gui_command, str):
                        self.process_gui_command(gui_command)
                    else:
                        self.process_gui_command(gui_command)
                    last_gui_heartbeat = current_time
                    gui_connected = True
                    consecutive_errors = 0
                except Exception as e:
                    print(f"Error processing GUI command: {e}")

            # 2. Read Pico Responses & Trigger Immediate Update
            if self.read_pico_response():
                self.update_status()
                last_status_time = current_time

            # 3. Poll Pico Status
            if current_time - last_pico_status_req > pico_status_interval:
                if self.pico_serial:
                    self.send_to_pico("status")
                last_pico_status_req = current_time

            # 4. Safety checks
            if current_time - last_safety_check > safety_check_interval:
                self.perform_safety_checks()
                last_safety_check = current_time

            # 5. Heartbeat monitoring
            if current_time - last_heartbeat_check > heartbeat_check_interval:
                if gui_connected and current_time - last_gui_heartbeat > self.heartbeat_timeout:
                    print("GUI heartbeat timeout - activating safety stop")
                    self.emergency_stop = True
                    self.send_to_pico("stop")
                last_heartbeat_check = current_time

            # 6. Periodic Status Heartbeat (if no updates recently)
            if current_time - last_status_time > status_interval:
                self.update_status()
                last_status_time = current_time

            # 7. Run motor control loop if using local controller
            if self.motor_controller and not self.emergency_stop:
                try:
                    if self.motor_controller.control_mode == "position":
                        self.motor_controller.position_control()
                    elif self.motor_controller.control_mode == "velocity":
                        self.motor_controller.velocity_control()
                except Exception as e:
                    print(f"Motor control error: {e}")
                    self.emergency_stop = True

            # High speed loop sleep
            time.sleep(0.002)  # ~500Hz

    def shutdown(self):
        """Clean shutdown"""
        if self.pico_serial:
            self.send_to_pico("stop")
            self.pico_serial.close()

        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass

        if self.motor_controller:
            self.motor_controller.stop_motor()

        print("Lathe controller shut down")

def main():
    print("Haptic Lathe Controller Starting...")

    # Check environment variable first (from launcher)
    env_port = os.environ.get("PICO_SERIAL_PORT")
    
    # List of ports to try
    pico_ports = []
    if env_port:
        pico_ports.append(env_port)
        
    # Add fallbacks
    pico_ports.extend(["/dev/cu.usbmodem11401", "/dev/cu.usbmodem1401", "/dev/cu.usbmodem2101", "/dev/tty.usbmodem2101", "/dev/ttyACM1", "/dev/ttyUSB1", "COM5", "COM6"])

    controller = None

    # Try to connect
    for pico_port in pico_ports:
        try:
            print(f"Attempting connection on {pico_port}...")
            controller = LatheController(pico_serial_port=pico_port)
            if controller.pico_serial:
                print(f"Successfully connected to Pico on {pico_port}")
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
