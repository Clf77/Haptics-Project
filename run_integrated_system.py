#!/usr/bin/env python3
"""
Integrated Haptic Lathe System Launcher
Starts both the Python bridge controller and Processing GUI
"""

import subprocess
import sys
import os
import time
import signal
import threading
from pathlib import Path

class IntegratedLauncher:
    def __init__(self):
        self.controller_process = None
        self.processing_process = None
        self.running = True

        # Install signal handler for clean shutdown
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)

    def signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        print("\nReceived shutdown signal, stopping all processes...")
        self.running = False
        self.cleanup()

    def check_dependencies(self):
        """Check if required dependencies are installed"""
        print("Checking dependencies...")

        # Check Python dependencies
        try:
            import serial
            import json
            print("✓ Python dependencies OK")
        except ImportError as e:
            print(f"✗ Missing Python dependency: {e}")
            print("Install with: pip install pyserial")
            return False

        # Check if Processing is available
        processing_found = False
        try:
            result = subprocess.run(["which", "processing"],
                                  capture_output=True, text=True)
            if result.returncode == 0:
                processing_found = True
                print("✓ Processing IDE found")
        except:
            pass

        if not processing_found:
            try:
                # Check if Processing.app exists on macOS
                processing_app = Path("/Applications/Processing.app")
                if processing_app.exists():
                    processing_found = True
                    print("✓ Processing.app found")
            except:
                pass

        if not processing_found:
            print("✗ Processing IDE not found")
            print("Please install Processing from: https://processing.org/")
            return False

        return True

    def find_serial_ports(self):
        """Find available serial ports for GUI and Pico"""
        import serial.tools.list_ports

        ports = list(serial.tools.list_ports.comports())
        available_ports = [port.device for port in ports]

        print(f"Available serial ports: {available_ports}")

        # Try to identify GUI and Pico ports
        gui_port = None
        pico_port = None

        # Improved port detection for macOS
        for port in available_ports:
            # Check for common Pico/Arduino port names
            if "usbmodem" in port or "ACM" in port or "USB" in port:
                if not gui_port:
                    gui_port = port
                elif not pico_port:
                    pico_port = port
        
        # If only one port found, assume it's the Pico (since GUI is file-based now)
        if gui_port and not pico_port:
            pico_port = gui_port
            gui_port = None

        return gui_port, pico_port

    def start_controller(self, gui_port=None, pico_port=None):
        """Start the Python bridge controller"""
        print("Starting bridge controller...")

        cmd = [sys.executable, "integrated_lathe_controller.py"]

        # Set environment variables for port configuration
        env = os.environ.copy()
        if gui_port:
            env["GUI_SERIAL_PORT"] = gui_port
        if pico_port:
            env["PICO_SERIAL_PORT"] = pico_port

        try:
            self.controller_process = subprocess.Popen(
                cmd,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            print("✓ Bridge controller started")
            return True
        except Exception as e:
            print(f"✗ Failed to start controller: {e}")
            return False

    def start_processing_gui(self):
        """Start the Processing GUI"""
        print("Starting Processing GUI...")

        # Correct path to sketch
        sketch_path = os.path.join("Haptic_Lathe_GUI", "Haptic_Lathe_GUI_Integrated.pde")

        if not os.path.exists(sketch_path):
            print(f"✗ Sketch file not found: {sketch_path}")
            return False

        try:
            # Use Processing IDE to open the sketch
            if os.name == 'posix':  # macOS/Linux
                processing_app = "/Applications/Processing.app/Contents/MacOS/Processing"
                if os.path.exists(processing_app):
                    # Open Processing IDE with the sketch directory
                    cmd = ["open", "-a", "Processing", sketch_path]
                else:
                    print("✗ Processing IDE not found at expected location")
                    return False
            else:  # Windows
                print("✗ Windows Processing launch not implemented")
                return False

            self.processing_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True
            )
            print("✓ Processing GUI opened - you may need to click 'Run' in the IDE")
            return True
        except Exception as e:
            print(f"✗ Failed to start Processing GUI: {e}")
            return False

    def monitor_processes(self):
        """Monitor running processes and handle output"""
        def monitor_output(process, name):
            if process and process.stdout:
                for line in iter(process.stdout.readline, ''):
                    if line.strip():
                        print(f"[{name}] {line.strip()}")

        # Start monitoring threads
        if self.controller_process:
            controller_thread = threading.Thread(
                target=monitor_output,
                args=(self.controller_process, "CONTROLLER"),
                daemon=True
            )
            controller_thread.start()

        if self.processing_process:
            processing_thread = threading.Thread(
                target=monitor_output,
                args=(self.processing_process, "PROCESSING"),
                daemon=True
            )
            processing_thread.start()

    def wait_for_user_input(self):
        """Wait for user input to stop the system"""
        print("\n" + "="*60)
        print("INTEGRATED HAPTIC LATHE SYSTEM RUNNING")
        print("="*60)
        print("Processes:")
        if self.controller_process:
            print("✓ Bridge Controller (Python)")
        if self.processing_process:
            print("✓ Processing GUI")
        print("\nControls:")
        print("- Press Ctrl+C to stop all processes")
        print("- Check the Processing window for the GUI")
        print("- Use spacebar in GUI for emergency stop")
        print("- Press 'P' in GUI to toggle physical/mouse input")
        print("="*60)

        try:
            while self.running:
                time.sleep(1)

                # Check if processes are still alive
                if self.controller_process and self.controller_process.poll() is not None:
                    print("Bridge controller process ended")
                    self.running = False
                
                # On macOS with 'open', the process ends immediately, so we don't monitor it
                # Only monitor if we're not using 'open' (which we can infer or set a flag)
                # For now, we'll just disable strict monitoring of the GUI process to avoid premature shutdown
                # if self.processing_process and self.processing_process.poll() is not None:
                #     print("Processing GUI process ended")
                #     self.running = False

        except KeyboardInterrupt:
            print("\nShutdown requested by user")

    def cleanup(self):
        """Clean up running processes"""
        print("Cleaning up processes...")

        if self.controller_process and self.controller_process.poll() is None:
            print("Stopping bridge controller...")
            self.controller_process.terminate()
            try:
                self.controller_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                print("Force killing bridge controller...")
                self.controller_process.kill()

        if self.processing_process and self.processing_process.poll() is None:
            print("Stopping Processing GUI...")
            self.processing_process.terminate()
            try:
                self.processing_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                print("Force killing Processing GUI...")
                self.processing_process.kill()

        print("Cleanup complete")

    def run(self):
        """Main run method"""
        print("Integrated Haptic Lathe System Launcher")
        print("=" * 40)

        # Check dependencies
        if not self.check_dependencies():
            return 1

        # Find serial ports
        gui_port, pico_port = self.find_serial_ports()

        if gui_port:
            print(f"GUI port: {gui_port}")
        else:
            print("No GUI serial port detected (this is OK if using local controller)")

        if pico_port:
            print(f"Pico port: {pico_port}")
        else:
            print("No Pico serial port detected (will use local motor controller)")

        # Start controller
        if not self.start_controller(gui_port, pico_port):
            print("Failed to start system")
            return 1

        # Give controller time to initialize
        time.sleep(2)

        # Start Processing GUI
        if not self.start_processing_gui():
            print("Failed to start Processing GUI")
            self.cleanup()
            return 1

        # Start monitoring
        self.monitor_processes()

        # Wait for user input
        self.wait_for_user_input()

        # Cleanup
        self.cleanup()

        print("System shutdown complete")
        return 0

def main():
    launcher = IntegratedLauncher()
    try:
        return launcher.run()
    except Exception as e:
        print(f"Unexpected error: {e}")
        launcher.cleanup()
        return 1

if __name__ == "__main__":
    sys.exit(main())
