# 📤 Upload motor_control.py to Raspberry Pi Pico

## ⚠️ **PICO IS IN BOOTSEL MODE - READY FOR UPLOAD**

Since your Pico is showing up in Finder (BOOTSEL mode), follow these steps:

## 📋 **Upload Steps:**

### **1. Open Thonny IDE**
- If you don't have Thonny: Download from https://thonny.org/
- Open Thonny on your Mac

### **2. Connect to Pico**
- In Thonny: `Run` → `Select interpreter`
- Choose: `MicroPython (Raspberry Pi Pico)`
- Select the Pico device (should appear as `/dev/cu.usbmodemXXXX`)

### **3. Upload motor_control.py**
- Open the file: `File` → `Open` → Navigate to `pico_upload/motor_control.py`
- Or copy the content from `motor_control.py` in the root directory
- Save to Pico: `File` → `Save as` → Choose `Raspberry Pi Pico`

### **4. Upload test_motor.py (optional but recommended)**
- Also upload `pico_upload/test_motor.py` for testing
- This will help verify hardware works

### **5. Restart Pico**
- Unplug and replug the Pico (exit BOOTSEL mode)
- Thonny should reconnect automatically

## 🧪 **Test the Upload**

### **In Thonny Shell (after upload):**
```python
# Import and test
from motor_control import MotorController
motor = MotorController()
print("Motor controller initialized!")

# Test status
motor.get_position_degrees()
motor.get_velocity_rpm()
```

### **Expected Output:**
```
Motor controller initialized
Encoder CPR: 64, Gear ratio: 30.0
Counts per output revolution: 1920.0
```

## ⚡ **Quick Hardware Test**

Once uploaded, run this in Thonny:

```python
# Test encoder
from motor_control import MotorController
motor = MotorController()

print("Current position:", motor.get_position_degrees())
print("Rotate motor manually, then check again...")

# Wait a few seconds, then:
print("New position:", motor.get_position_degrees())
```

## 🔌 **If Upload Fails:**

### **Check Connections:**
- Pico properly inserted
- USB cable working
- No other programs using the port

### **Reset Pico:**
- Hold BOOTSEL while plugging in
- Should appear as USB drive in Finder

### **Alternative Upload:**
```bash
# If Thonny fails, try command line:
cp motor_control.py /Volumes/RPI-RP2/
cp test_motor.py /Volumes/RPI-RP2/
```

## 🎯 **After Successful Upload:**

Run our test script:
```bash
python3 test_real_hardware.py
```

This will test:
- ✅ Pico connection
- ✅ Encoder reading
- ✅ Motor movement
- ✅ Position control
- ✅ Full integration

## 🚨 **Hardware Pin Verification:**

Double-check your wiring:
```
CQR37D Motor → DROK XY-160D → Raspberry Pi Pico

ENA (PWM) → GP0 (Pin 1)
IN1 (DIR) → GP1 (Pin 2)
GND → GND
+Power → Motor Power Supply

Encoder A (White) → GP8 (Pin 9)
Encoder B (Yellow) → GP9 (Pin 10)
Encoder GND → GND
Encoder +3.3V → 3.3V
```

**Ready to upload? Let me know when it's done and we'll test the real hardware!** 🔬⚙️
