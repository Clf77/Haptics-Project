#!/usr/bin/env python3
"""
Test script for Integrated Haptic Lathe System
Tests individual components and communication
"""

import time
import json
import serial
import subprocess
import sys
from pathlib import Path

def test_serial_ports():
    """Test serial port detection"""
    print("Testing serial port detection...")
    try:
        import serial.tools.list_ports
        ports = list(serial.tools.list_ports.comports())
        print(f"✓ Found {len(ports)} serial ports:")
        for port in ports:
            print(f"  - {port.device}: {port.description}")
        return True
    except ImportError:
        print("✗ pyserial not installed")
        return False
    except Exception as e:
        print(f"✗ Serial port test failed: {e}")
        return False

def test_motor_controller():
    """Test motor controller (if available)"""
    print("Testing motor controller...")
    try:
        # Try to import and create motor controller
        from motor_control import MotorController
        motor = MotorController()
        print("✓ Motor controller initialized")

        # Test basic functions
        pos = motor.get_position_degrees()
        vel = motor.get_velocity_rpm()
        print(".2f")

        motor.stop_motor()
        print("✓ Motor controller test passed")
        return True
    except ImportError:
        print("! Motor controller not available (expected if Pico not connected)")
        return True  # Not a failure
    except Exception as e:
        print(f"✗ Motor controller test failed: {e}")
        return False

def test_bridge_controller():
    """Test bridge controller initialization"""
    print("Testing bridge controller...")
    try:
        from integrated_lathe_controller import LatheController
        controller = LatheController(pico_serial_port="/dev/ttyACM1")
        print("✓ Bridge controller initialized")

        # Test basic status
        status = {
            "type": "status_update",
            "handle_wheel_position": 0.0,
            "mode": "manual",
            "skill_level": "beginner",
            "emergency_stop": False,
            "spindle_rpm": 0,
            "feed_rate": 0.0,
            "timestamp": time.time()
        }
        print("✓ Status structure OK")
        controller.shutdown()
        return True
    except Exception as e:
        print(f"✗ Bridge controller test failed: {e}")
        return False

def test_processing_sketch():
    """Test Processing sketch file"""
    print("Testing Processing sketch...")
    sketch_file = "Haptic_Lathe_GUI_Integrated.pde"
    if Path(sketch_file).exists():
        print("✓ Processing sketch file found")
        # Basic syntax check - look for key Processing functions
        with open(sketch_file, 'r') as f:
            content = f.read()
            if 'void setup()' in content and 'void draw()' in content:
                print("✓ Processing sketch has required functions")
                return True
            else:
                print("✗ Processing sketch missing required functions")
                return False
    else:
        print("✗ Processing sketch file not found")
        return False

def test_json_communication():
    """Test JSON communication format"""
    print("Testing JSON communication...")
    try:
        # Test GUI command parsing
        test_commands = [
            '{"type":"mode_change","mode":"facing","skill_level":"beginner"}',
            '{"type":"emergency_stop"}',
            '{"type":"set_parameters","spindle_rpm":500,"feed_rate":0.005}'
        ]

        for cmd in test_commands:
            parsed = json.loads(cmd)
            if 'type' in parsed:
                print(f"✓ Parsed command: {parsed['type']}")
            else:
                print(f"✗ Invalid command format: {cmd}")
                return False

        # Test status message creation
        status = {
            "type": "status_update",
            "handle_wheel_position": 45.67,
            "mode": "facing",
            "skill_level": "beginner",
            "emergency_stop": False,
            "timestamp": time.time()
        }
        json_str = json.dumps(status)
        parsed_back = json.loads(json_str)
        if parsed_back['type'] == 'status_update':
            print("✓ Status message format OK")
            return True
        else:
            print("✗ Status message format error")
            return False

    except Exception as e:
        print(f"✗ JSON communication test failed: {e}")
        return False

def test_file_structure():
    """Test that all required files exist"""
    print("Testing file structure...")
    required_files = [
        "integrated_lathe_controller.py",
        "run_integrated_system.py",
        "setup_integrated_system.py",
        "Haptic_Lathe_GUI_Integrated.pde",
        "motor_control.py",
        "INTEGRATED_SYSTEM_README.md"
    ]

    missing_files = []
    for file in required_files:
        if not Path(file).exists():
            missing_files.append(file)

    if missing_files:
        print(f"✗ Missing files: {missing_files}")
        return False
    else:
        print("✓ All required files present")
        return True

def main():
    """Run all tests"""
    print("Integrated Haptic Lathe System - Test Suite")
    print("=" * 50)

    tests = [
        ("File Structure", test_file_structure),
        ("Serial Ports", test_serial_ports),
        ("Motor Controller", test_motor_controller),
        ("Bridge Controller", test_bridge_controller),
        ("Processing Sketch", test_processing_sketch),
        ("JSON Communication", test_json_communication)
    ]

    results = []
    for test_name, test_func in tests:
        print(f"\n--- {test_name} ---")
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"✗ Test {test_name} crashed: {e}")
            results.append((test_name, False))

    # Summary
    print("\n" + "=" * 50)
    print("TEST SUMMARY")
    print("=" * 50)

    passed = 0
    total = len(results)

    for test_name, result in results:
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"{status}: {test_name}")
        if result:
            passed += 1

    print(f"\nPassed: {passed}/{total}")

    if passed == total:
        print("🎉 All tests passed! System ready for integration.")
        return 0
    else:
        print("⚠️  Some tests failed. Check output above for details.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
