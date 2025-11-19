#!/usr/bin/env python3
"""
FINAL UPLOAD GUIDE - Since BOOTSEL is enabled
Follow these exact steps to upload your motor control system
"""

import os

def print_step(step_num, title, instructions):
    print(f"\n🔸 STEP {step_num}: {title}")
    print(f"{'─' * (len(title) + 10)}")
    for instruction in instructions:
        print(f"   {instruction}")

def main():
    print("=" * 70)
    print("🎯 FINAL UPLOAD GUIDE - Pico is in BOOTSEL Mode")
    print("=" * 70)

    print("\n✅ CONFIRMED: Your Pico should now appear as 'RPI-RP2' drive on your computer")

    # Step 1: Verify files
    print_step(1, "VERIFY FILES ARE READY",
        ["Check that these files exist in your project folder:",
         "  ✓ motor_control.py",
         "  ✓ test_motor.py",
         "  ✓ calibrate_motor.py",
         "  ✓ quick_test.py"])

    # Check files exist
    files = ['motor_control.py', 'test_motor.py', 'calibrate_motor.py', 'quick_test.py']
    missing = [f for f in files if not os.path.exists(f)]
    if missing:
        print(f"❌ MISSING FILES: {missing}")
        return

    print("✅ All files verified!")

    # Step 2: Open Thonny
    print_step(2, "OPEN THONNY IDE",
        ["Make sure Thonny IDE is installed and open",
         "If not installed: Download from https://thonny.org/",
         "Open Thonny on your computer (not in browser)"])

    # Step 3: Configure for Pico
    print_step(3, "CONFIGURE THONNY FOR PICO",
        ["In Thonny: Click Tools → Options → Interpreter tab",
         "Select: 'MicroPython (Raspberry Pi Pico)'",
         "Port should auto-detect (or select it)",
         "Click OK",
         "Thonny should connect to your Pico"])

    # Step 4: Upload files
    print_step(4, "UPLOAD THE 4 PYTHON FILES",
        ["In Thonny's left panel, you should see 'Raspberry Pi Pico'",
         "On your computer, find your project folder",
         "DRAG each file from computer to Pico panel:",
         "  → motor_control.py",
         "  → test_motor.py",
         "  → calibrate_motor.py",
         "  → quick_test.py",
         "Wait for all uploads to complete"])

    # Step 5: Verify upload
    print_step(5, "VERIFY UPLOAD SUCCESS",
        ["Files should appear in Pico panel with correct sizes",
         "Click the 'Play' button (or F5) to restart Pico",
         "Open REPL (bottom panel in Thonny)"])

    # Step 6: Test system
    print_step(6, "TEST YOUR MOTOR CONTROL SYSTEM",
        ["In REPL, type these commands one by one:",
         "",
         "from motor_control import MotorController",
         "motor = MotorController()",
         "print('✓ System initialized!')",
         "",
         "# Quick motor test (be careful!)",
         "motor.set_motor_speed(5)  # Slow test",
         "import time; time.sleep(2)",
         "motor.stop_motor()",
         "print('✓ Motor test passed!')"])

    # Success message
    print(f"\n{'🎉' * 10}")
    print("CONGRATULATIONS! Your motor control system is now live!")
    print(f"{'🎉' * 10}")

    print("\n🚀 QUICK START COMMANDS:")
    print("• Run full tests: exec(open('test_motor.py').read())")
    print("• Interactive control: exec(open('motor_control.py').read())")
    print("  Then use commands like: vel 30, pos 90, status, stop")

    print(f"\n{'─' * 70}")

if __name__ == "__main__":
    main()
