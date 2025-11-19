#!/usr/bin/env python3
"""
Setup verification script for CQR37D motor control
Run this to check if your environment is ready for Pico development
"""

import sys
import subprocess
import os

def check_python():
    """Check Python version"""
    print(f"✓ Python {sys.version.split()[0]}")

def check_thonny():
    """Check if Thonny is installed"""
    try:
        result = subprocess.run(['which', 'thonny'], capture_output=True, text=True)
        if result.returncode == 0:
            print("✓ Thonny IDE found")
            return True
        else:
            print("✗ Thonny IDE not found")
            return False
    except:
        print("✗ Thonny IDE not found")
        return False

def check_micropython_tools():
    """Check for MicroPython development tools"""
    tools = ['ampy', 'rshell', 'mpremote', 'picotool']
    found = False
    for tool in tools:
        try:
            result = subprocess.run(['which', tool], capture_output=True, text=True)
            if result.returncode == 0:
                print(f"✓ {tool} found")
                found = True
        except:
            pass
    if not found:
        print("ℹ️  No MicroPython tools found (Thonny is recommended)")

def check_pico_files():
    """Check if Pico files exist"""
    files = ['motor_control.py', 'test_motor.py', 'calibrate_motor.py', 'quick_test.py']
    missing = []
    for file in files:
        if os.path.exists(file):
            print(f"✓ {file} ready")
        else:
            missing.append(file)
            print(f"✗ {file} missing")

    if missing:
        print(f"\n❌ Missing files: {', '.join(missing)}")
        return False
    else:
        print("\n✅ All Pico files ready!")
        return True

def main():
    print("=" * 50)
    print("🧪 RASPBERRY PI PICO SETUP VERIFICATION")
    print("=" * 50)

    print("\n🔍 Checking development environment...")
    check_python()
    check_thonny()
    check_micropython_tools()

    print("\n📁 Checking project files...")
    files_ready = check_pico_files()

    print("\n" + "=" * 50)
    if files_ready:
        print("🎉 READY TO UPLOAD!")
        print("\n📋 Next Steps:")
        print("1. Open Thonny IDE")
        print("2. Connect Pico (BOOTSEL + USB)")
        print("3. Drag files from project folder to Pico")
        print("4. Open REPL and run: from motor_control import MotorController")
    else:
        print("❌ SETUP INCOMPLETE")
        print("Please ensure all files are present before uploading.")

    print("=" * 50)

if __name__ == "__main__":
    main()
