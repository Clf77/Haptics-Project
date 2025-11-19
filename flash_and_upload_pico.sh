#!/bin/bash
# Automated Pico flashing and code upload script

echo "🔧 RASPBERRY PI PICO - FLASH AND UPLOAD SCRIPT"
echo "=============================================="

# Check if Pico is in BOOTSEL mode
if [ ! -d "/Volumes/RPI-RP2" ]; then
    echo "❌ ERROR: Pico not in BOOTSEL mode!"
    echo ""
    echo "Please put Pico in BOOTSEL mode:"
    echo "1. Hold BOOTSEL button"
    echo "2. Unplug Pico"
    echo "3. Plug back in while holding BOOTSEL"
    echo "4. Release BOOTSEL button"
    echo "5. Run this script again"
    exit 1
fi

echo "✅ Pico detected in BOOTSEL mode"

# Check for MicroPython UF2
if [ ! -f "micropython.uf2" ]; then
    echo "❌ ERROR: micropython.uf2 not found!"
    echo "Download from: https://micropython.org/download/rp2-pico/"
    exit 1
fi

echo "✅ MicroPython UF2 found"

# Check for motor control files
if [ ! -f "pico_upload/motor_control.py" ]; then
    echo "❌ ERROR: pico_upload/motor_control.py not found!"
    exit 1
fi

echo "✅ Motor control files found"

# Step 1: Flash MicroPython UF2
echo ""
echo "📤 Step 1: Flashing MicroPython UF2..."
cp micropython.uf2 "/Volumes/RPI-RP2/"
if [ $? -eq 0 ]; then
    echo "✅ MicroPython UF2 copied to Pico"
else
    echo "❌ Failed to copy UF2 file"
    exit 1
fi

# Wait for Pico to restart
echo "⏳ Waiting for Pico to restart (10 seconds)..."
sleep 10

# Step 2: Put Pico back in BOOTSEL mode for file upload
echo ""
echo "🔄 Step 2: NOW PUT PICO BACK IN BOOTSEL MODE"
echo "1. Hold BOOTSEL button"
echo "2. Unplug Pico"
echo "3. Plug back in while holding BOOTSEL"
echo "4. Press ENTER when RPI-RP2 appears in Finder"
read -p "Press ENTER when ready..."

# Check if Pico is in BOOTSEL mode again
if [ ! -d "/Volumes/RPI-RP2" ]; then
    echo "❌ ERROR: Pico not detected in BOOTSEL mode!"
    exit 1
fi

echo "✅ Pico back in BOOTSEL mode"

# Step 3: Upload motor control files
echo ""
echo "📤 Step 3: Uploading motor control files..."

# Upload motor_control.py
if command -v rsync &> /dev/null; then
    rsync -av pico_upload/motor_control.py "/Volumes/RPI-RP2/"
    rsync -av pico_upload/test_motor.py "/Volumes/RPI-RP2/"
else
    cp pico_upload/motor_control.py "/Volumes/RPI-RP2/"
    cp pico_upload/test_motor.py "/Volumes/RPI-RP2/"
fi

# Verify files were copied
if [ -f "/Volumes/RPI-RP2/motor_control.py" ]; then
    echo "✅ motor_control.py uploaded"
else
    echo "❌ Failed to upload motor_control.py"
    exit 1
fi

if [ -f "/Volumes/RPI-RP2/test_motor.py" ]; then
    echo "✅ test_motor.py uploaded"
else
    echo "❌ Failed to upload test_motor.py"
    exit 1
fi

# Step 4: Eject Pico
echo ""
echo "📤 Step 4: Ejecting Pico..."
diskutil eject "/Volumes/RPI-RP2" 2>/dev/null || true

echo ""
echo "⏳ Waiting for Pico to restart (5 seconds)..."
sleep 5

# Step 5: Test connection
echo ""
echo "🧪 Step 5: Testing motor control..."
python3 << 'EOF'
import serial
import serial.tools.list_ports
import time

# Find Pico
ports = list(serial.tools.list_ports.comports())
pico_port = None

for port in ports:
    if 'usbmodem' in port.device:
        pico_port = port.device
        break

if not pico_port:
    print("❌ Pico not found as serial device")
    print("Available ports:")
    for port in ports:
        print(f"  {port.device}: {port.description}")
    exit(1)

print(f"✅ Pico found: {pico_port}")

# Test motor control
try:
    ser = serial.Serial(pico_port, 115200, timeout=2)
    print("🎯 Testing motor control import...")
    
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    time.sleep(0.2)
    
    # Import motor control
    ser.write(b'import motor_control\n')
    time.sleep(1)
    
    ser.write(b'motor = motor_control.MotorController()\n')
    time.sleep(1)
    
    ser.write(b'print("Encoder position:", motor.get_position_degrees())\n')
    time.sleep(0.5)
    
    # Read response
    response = ''
    start_time = time.time()
    while time.time() - start_time < 3:
        if ser.in_waiting:
            response += ser.read().decode()
    
    if 'Motor controller initialized' in response:
        print("✅ SUCCESS! Motor control is working!")
        print("")
        print("🎉 CQR37D motor and encoder are ready for testing!")
        print("")
        print("Next steps:")
        print("1. Run: python3 test_real_hardware.py")
        print("2. Or run: python3 integrated_lathe_controller.py")
    else:
        print("❌ Motor control not responding correctly")
        print(f"Response: {repr(response)}")
    
    ser.close()
    
except Exception as e:
    print(f"❌ Error: {e}")
EOF

echo ""
echo "✅ FLASH AND UPLOAD COMPLETE!"

