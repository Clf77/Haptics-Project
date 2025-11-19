"""Simple encoder test for CQR37D motor"""
from machine import Pin
import time

# Setup encoder pins
enc_a = Pin(8, Pin.IN, Pin.PULL_UP)
enc_b = Pin(9, Pin.IN, Pin.PULL_UP)

print("CQR37D Encoder Test")
print("=" * 40)
print("ROTATE THE MOTOR MANUALLY")
print("Press Ctrl-C to stop")
print()
print("Time    A  B")
print("-" * 20)

try:
    while True:
        a_val = enc_a.value()
        b_val = enc_b.value()
        print(f"{time.ticks_ms()/1000:6.1f}  {a_val}  {b_val}")
        time.sleep(0.1)
except KeyboardInterrupt:
    print("\nTest stopped")

