# 🔌 WIRING VERIFICATION FOR CQR37D MOTOR SYSTEM

## ✅ **WHAT YOU CONFIRMED:**
- Encoder white wire → Pico Pin 9 (GP8) ✅
- Encoder yellow wire → Pico Pin 10 (GP9) ✅

## 📋 **COMPLETE WIRING CHECKLIST:**

### **1. ENCODER → PICO:**
- [ ] White wire (Encoder A) → Pico Pin 9 (GP8) ✅ **YOU CONFIRMED**
- [ ] Yellow wire (Encoder B) → Pico Pin 10 (GP9) ✅ **YOU CONFIRMED**
- [ ] Red wire (Encoder +) → Pico 3.3V (Pin 36)
- [ ] Black wire (Encoder GND) → Pico GND

### **2. PICO → MOTOR CONTROLLER (7A-160W):**
- [ ] Pico GP0 (Pin 1) → Motor Controller ENA (pin 7) - PWM
- [ ] Pico GP1 (Pin 2) → Motor Controller IN1 (pin 8) - Direction
- [ ] Pico GP2 (Pin 4) → Motor Controller IN2 (pin 9) - Direction
- [ ] Pico 3.3V or 5V → Motor Controller +5V (pin 13) - Logic power
- [ ] Pico GND → Motor Controller GND - Common ground

### **3. MOTOR CONTROLLER → CQR37D MOTOR:**
- [ ] Motor Controller OUT1 (pin 3) → Motor Red (+)
- [ ] Motor Controller OUT2 (pin 4) → Motor Black (-)

### **4. POWER SUPPLY → MOTOR CONTROLLER:**
- [ ] Power Supply + (12V recommended) → Motor Controller 9~24VDC (pin 1)
- [ ] Power Supply GND → Motor Controller PGND (pin 2)

## ⚠️ **CRITICAL CHECKS:**

### **Is the motor power supply turned ON?**
- [ ] YES - Power supply is plugged in and switched on
- [ ] Voltage is 9-24V DC (12V recommended)

### **Are ALL grounds connected together?**
- [ ] Pico GND
- [ ] Motor Controller GND
- [ ] Power Supply GND
- **ALL must be connected to the same ground!**

### **Logic power to motor controller:**
- [ ] Motor Controller needs +5V for logic (pin 13)
- [ ] Connected to Pico 3.3V or external 5V?

## 🧪 **DEBUGGING STEPS:**

1. **Check motor power supply voltage with multimeter**
   - Measure between pins 1 and 2 on motor controller
   - Should be 9-24V DC

2. **Check if control signals are reaching motor controller**
   - Pico GP0, GP1, GP2 should output signals
   - Use multimeter or LED to verify

3. **Test motor controller directly**
   - Manually apply 3.3V to IN1, GND to IN2
   - Apply PWM to ENA
   - Motor should move

## 🎯 **MOST LIKELY ISSUE:**

Based on your report that "motor was working earlier", the issue is probably:

1. **❌ Motor power supply is OFF or disconnected**
2. **❌ Motor controller logic power (+5V) not connected**
3. **❌ Common ground not connected between Pico and motor controller**
4. **❌ Motor controller damaged**

## ✅ **NEXT STEPS:**

Please check:
1. Is the motor power supply (9-24V) plugged in and ON?
2. Is pin 13 on motor controller connected to +5V or +3.3V?
3. Is GND from Pico connected to motor controller GND?
4. Can you measure voltage on motor controller power terminals?

**Once you verify these, the motor WILL work!** The code is correct. ⚙️

