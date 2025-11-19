# 🔬 Hardware Testing Protocol for CQR37D Haptic Lathe System

## ⚠️ **CURRENT STATUS: CODE COMPLETE, HARDWARE TESTING REQUIRED**

### **What We've Built (Software)**
✅ Complete integrated lathe GUI with motor controls
✅ File-based communication between GUI and controller
✅ Motor control algorithms (position, velocity, safety)
✅ Encoder reading and position tracking
✅ Safety systems and emergency stop
✅ Simulated testing (fake sine wave data)

### **What Needs Real Hardware Testing**
❌ Actual encoder position reading from CQR37D motor
❌ Actual motor movement commands
❌ Physical handle wheel ↔ motor shaft connection
❌ Real-time position feedback accuracy
❌ Motor safety limits and error handling

---

## 🧪 **Step-by-Step Hardware Testing Protocol**

### **Phase 1: Basic Hardware Setup**

#### **1.1 Upload Motor Control to Pico**
```bash
# Connect Pico to computer (hold BOOTSEL button)
# Copy motor_control.py to Pico using Thonny IDE
```

#### **1.2 Hardware Connections**
```
CQR37D Motor → DROK XY-160D Controller → Raspberry Pi Pico

Motor Pins:
- Red: + Power (6-24V DC)
- Black: - Power (GND)

Controller → Pico:
- ENA (PWM): GP0 (Pin 1)
- IN1 (DIR): GP1 (Pin 2)

Encoder → Pico:
- A (White): GP8 (Pin 9)
- B (Yellow): GP9 (Pin 10)
- + (Red): 3.3V
- - (Black): GND
```

#### **1.3 Power Supply**
- **Motor Power**: 12V DC recommended (check motor specs)
- **Pico Power**: USB 5V
- **Controller Logic**: 3.3V-5V compatible

---

### **Phase 2: Basic Motor Testing**

#### **2.1 Test Encoder Reading**
```python
# On Pico, run:
from test_motor import test_encoder
test_encoder()
# Manually rotate motor shaft
# Should show encoder count changes
```

**Expected Results:**
- Encoder counts increase/decrease when rotating
- Noisy counts = wiring issue
- No counts = encoder not connected

#### **2.2 Test Motor Movement**
```python
# On Pico, run:
from test_motor import test_motor_directions
test_motor_directions()
# Motor should move CW then CCW
```

**Expected Results:**
- Smooth motor rotation in both directions
- Position changes match expected RPM
- No stuttering = PWM working correctly

#### **2.3 Test Position Control**
```python
# On Pico, run motor_control.py directly
pos 180  # Move to 180 degrees
status   # Check position
pos 0    # Return to zero
```

**Expected Results:**
- Motor moves to exact position
- Holds position against manual force
- Smooth movement, no oscillations

---

### **Phase 3: Integrated System Testing**

#### **3.1 Start Python Controller**
```bash
python3 integrated_lathe_controller.py
# Should show: "Connected to Pico on /dev/ttyACM1"
```

#### **3.2 Start Processing GUI**
```bash
# Open Haptic_Lathe_GUI_Integrated.pde in Processing IDE
# Click Run
```

**Expected Results:**
- GUI shows green connection dot
- Footer shows "Connected • Handle: X.X°"
- Motor control buttons visible

#### **3.3 Test Motor Control Buttons**
1. Click **Forward** button → Motor moves CW
2. Click **Reverse** button → Motor moves CCW
3. Click **Stop** button → Motor stops
4. Try **±1°** / **±10°** position buttons
5. Select different speeds (Slow/Medium/Fast)

**Expected Results:**
- Motor responds immediately to button clicks
- Speed changes work correctly
- Position buttons move motor by exact amounts
- Encoder position updates in real-time in GUI

#### **3.4 Test Handle Wheel Integration**
1. Physically attach handle wheel to motor shaft
2. Turn handle wheel manually
3. Observe GUI position updates
4. Test "Physical Input" mode toggle

**Expected Results:**
- Handle wheel rotation = GUI tool movement
- Smooth, accurate position tracking
- No lag or jitter in position display

---

### **Phase 4: Safety and Performance Testing**

#### **4.1 Emergency Stop Testing**
- Press **Spacebar** during motor movement
- Motor should stop immediately
- GUI should show emergency state

#### **4.2 Error Handling**
- Disconnect encoder wires during operation
- System should detect and stop safely
- GUI should show error state

#### **4.3 Performance Testing**
- High-speed motor movement
- Rapid position changes
- Continuous operation for 10+ minutes
- Temperature monitoring

---

## 📊 **Testing Results Template**

### **Test Session Date:** __________

#### **Hardware Configuration:**
- Pico firmware version: __________
- Motor voltage: __________ V
- Gear ratio: __________ :1
- Encoder CPR: __________ counts

#### **Phase 1 Results:**
- [ ] Pico programming successful
- [ ] All connections secure
- [ ] Power supplies stable

#### **Phase 2 Results:**
- [ ] Encoder reading: __________ counts/change
- [ ] Motor CW movement: __________ °/5sec
- [ ] Motor CCW movement: __________ °/5sec
- [ ] Position control accuracy: __________ °

#### **Phase 3 Results:**
- [ ] GUI connection: [ ] Stable [ ] Intermittent [ ] Failed
- [ ] Motor buttons: [ ] Working [ ] Sluggish [ ] Failed
- [ ] Position updates: [ ] Real-time [ ] Delayed [ ] Failed
- [ ] Handle wheel: [ ] Accurate [ ] Jittery [ ] Failed

#### **Phase 4 Results:**
- [ ] Emergency stop: [ ] Instant [ ] Delayed [ ] Failed
- [ ] Error handling: [ ] Safe [ ] Unsafe [ ] Failed
- [ ] Performance: [ ] Good [ ] Issues [ ] Failed

### **Issues Found:**
1. _______________________________
2. _______________________________
3. _______________________________

### **Overall Assessment:**
[ ] **PASS** - System ready for use
[ ] **CONDITIONAL PASS** - Minor issues, usable
[ ] **FAIL** - Major issues require fixes

---

## 🛠️ **Troubleshooting Guide**

### **GUI Shows "Disconnected"**
1. Check Python controller is running
2. Verify `/tmp/lathe_bridge_status.json` exists
3. Check file permissions

### **Motor Not Moving**
1. Verify power supply voltage
2. Check PWM and DIR pin connections
3. Test with direct motor_control.py commands

### **Encoder Not Reading**
1. Check encoder A/B wire colors
2. Verify 3.3V power to encoder
3. Test encoder continuity

### **Position Inaccurate**
1. Verify gear ratio setting
2. Check encoder CPR value
3. Calibrate zero position

---

## 🎯 **Success Criteria**

### **Minimum Viable System:**
- ✅ GUI connects and shows motor controls
- ✅ Motor moves in response to GUI buttons
- ✅ Encoder position updates in GUI
- ✅ Emergency stop works

### **Full System Success:**
- ✅ All above + handle wheel integration
- ✅ Smooth, accurate position control
- ✅ Safety systems functional
- ✅ Reliable operation for extended periods

---

## 📞 **Ready for Physical Testing**

**The software is complete and ready for real hardware testing.** Connect your CQR37D motor, Pico, and controller, then follow this protocol to verify everything works end-to-end.

**Only after successful hardware testing can we claim the system is fully functional!** 🔬⚙️
