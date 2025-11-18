#!/usr/bin/env python3
"""
Automated Pico Upload and Test Script
This script helps upload all motor control files to Raspberry Pi Pico and run tests
"""

import os
import sys
import time
import subprocess

def print_header():
    print("=" * 60)
    print("🤖 RASPBERRY PI PICO MOTOR CONTROL UPLOAD & TEST")
    print("=" * 60)
    print()

def check_requirements():
    """Check if required tools are available"""
    print("🔍 Checking requirements...")

    # Check if Python is available
    print(f"✓ Python {sys.version.split()[0]}")

    # Check if we can find Thonny (optional but helpful)
    try:
        result = subprocess.run(['which', 'thonny'], capture_output=True, text=True)
        if result.returncode == 0:
            print("✓ Thonny IDE found")
        else:
            print("⚠️  Thonny IDE not found (you can still upload manually)")
    except:
        print("⚠️  Could not check for Thonny")

    print()

def list_files():
    """List all files to be uploaded"""
    print("📁 Files ready for upload:")
    files = ['motor_control.py', 'test_motor.py', 'calibrate_motor.py', 'quick_test.py']

    for file in files:
        if os.path.exists(file):
            size = os.path.getsize(file)
            print(f"  ✓ {file} ({size} bytes)")
        else:
            print(f"  ✗ {file} - MISSING!")

    print()

def pico_connection_instructions():
    """Print Pico connection instructions"""
    print("🔌 RASPBERRY PI PICO CONNECTION:")
    print("1. Hold BOOTSEL button on Pico while plugging into USB")
    print("2. Open Thonny IDE")
    print("3. Go to Tools → Options → Interpreter")
    print("4. Select 'MicroPython (Raspberry Pi Pico)'")
    print("5. Click OK")
    print()

def upload_instructions():
    """Print upload instructions"""
    print("📤 UPLOAD INSTRUCTIONS:")
    print("Method 1 - Drag & Drop (Easiest):")
    print("  • Drag files from 'pico_upload/' folder to Pico in Thonny")
    print()
    print("Method 2 - Manual Upload:")
    print("  • Open each .py file in Thonny")
    print("  • Save to Raspberry Pi Pico location")
    print()
    print("Files to upload:")
    print("  • motor_control.py    (main control script)")
    print("  • test_motor.py       (automated tests)")
    print("  • calibrate_motor.py  (calibration tools)")
    print("  • quick_test.py       (quick test commands)")
    print()

def verification_steps():
    """Print verification steps"""
    print("✅ VERIFICATION STEPS:")
    print("After upload, open Thonny REPL and run:")
    print()
    print("  from motor_control import MotorController")
    print("  motor = MotorController()")
    print("  print('Motor controller initialized!')")
    print("  print(f'Encoder CPR: {motor.CPR}')")
    print()
    print("Expected output:")
    print("  Motor controller initialized!")
    print("  Encoder CPR: 64")
    print()

def test_sequence():
    """Print the complete test sequence"""
    print("🧪 COMPLETE TEST SEQUENCE:")
    print()
    print("1. BASIC IMPORT TEST:")
    print("   from motor_control import MotorController")
    print("   motor = MotorController()")
    print("   print('✓ Import successful!')")
    print()
    print("2. ENCODER TEST (rotate motor manually):")
    print("   start = motor.encoder_count")
    print("   # Rotate motor 1 full turn")
    print("   import time; time.sleep(3)")
    print("   end = motor.encoder_count")
    print("   print(f'Counts: {end - start}')  # Should be ~1920")
    print()
    print("3. MOTOR MOVEMENT TEST:")
    print("   motor.set_motor_speed(10)  # 10 RPM")
    print("   time.sleep(2)")
    print("   print(f'Speed: {motor.get_velocity_rpm()} RPM')")
    print("   motor.stop_motor()")
    print()
    print("4. FULL AUTOMATED TEST:")
    print("   exec(open('test_motor.py').read())")
    print()
    print("5. INTERACTIVE CONTROL:")
    print("   exec(open('motor_control.py').read())")
    print("   # Then use commands like:")
    print("   # vel 30    (set 30 RPM)")
    print("   # pos 90    (move to 90 degrees)")
    print("   # status    (check position/speed)")
    print("   # stop      (stop motor)")
    print()

def emergency_stop():
    """Print emergency stop instructions"""
    print("🛑 EMERGENCY STOP:")
    print("If motor runs away or something goes wrong:")
    print("• Unplug power from motor controller")
    print("• Or run: motor.stop_motor() in REPL")
    print("• Or press Ctrl+C in Thonny")
    print()

def success_message():
    """Print success message"""
    print("🎉 UPLOAD COMPLETE CHECKLIST:")
    print("□ Pico connected and recognized by Thonny")
    print("□ All 4 .py files uploaded to Pico")
    print("□ Basic import test passed")
    print("□ Encoder responds to motor rotation")
    print("□ Motor moves in both directions")
    print("□ Velocity control works")
    print("□ Position control works")
    print()
    print("Once everything works, your motor control system is ready!")
    print("Use the command-line interface for normal operation.")
    print()

def main():
    print_header()
    check_requirements()
    list_files()

    print("🚀 UPLOAD PROCESS:")
    print("1. Connect your Pico (see instructions below)")
    print("2. Upload files using Thonny IDE")
    print("3. Verify upload with tests")
    print()

    pico_connection_instructions()
    upload_instructions()
    verification_steps()
    test_sequence()
    emergency_stop()
    success_message()

    print("=" * 60)
    print("📞 Need help? Check TESTING_GUIDE.md for detailed instructions")
    print("🔧 Having issues? Check README.md for troubleshooting")
    print("=" * 60)

if __name__ == "__main__":
    main()
