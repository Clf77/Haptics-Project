import os
import json
import time
import tempfile
import subprocess
import sys

def test_integration():
    print("🚀 Starting Headless Integration Test")
    
    # 1. Setup paths
    temp_dir = tempfile.gettempdir()
    cmd_file = os.path.join(temp_dir, "lathe_gui_commands.json")
    status_file = os.path.join(temp_dir, "lathe_bridge_status.json")
    
    print(f"📂 Command File: {cmd_file}")
    print(f"📂 Status File: {status_file}")
    
    # Clean up old files
    if os.path.exists(cmd_file): os.remove(cmd_file)
    if os.path.exists(status_file): os.remove(status_file)
    
    # 2. Start Bridge Controller
    print("\n🔌 Starting Bridge Controller...")
    bridge_process = subprocess.Popen(
        [sys.executable, "integrated_lathe_controller.py"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )
    
    # Non-blocking read of bridge output
    import fcntl
    fd = bridge_process.stdout.fileno()
    fl = fcntl.fcntl(fd, fcntl.F_GETFL)
    fcntl.fcntl(fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)
    
    def read_bridge_output():
        try:
            return bridge_process.stdout.read()
        except:
            return ""

    try:
        # Wait for initialization
        time.sleep(3)
        output = read_bridge_output()
        if output: print(f"[Bridge Output]\n{output}")
        
        # 3. Simulate "Enter Wall"
        print("\n🧱 TEST: Simulating Virtual Wall Entry (Force=100)")
        cmd = {"type": "haptic_feedback", "force": 100.0, "active": True}
        with open(cmd_file, 'w') as f:
            json.dump(cmd, f)
            
        # Wait for processing
        time.sleep(1)
        output = read_bridge_output()
        if output: print(f"[Bridge Output]\n{output}")
        
        if "spring_wall" in output or "Virtual wall" in output:
            print("✅ SUCCESS: Bridge processed wall entry command")
        else:
            print("⚠️  WARNING: Did not see explicit confirmation in logs (might be normal)")

        # 4. Simulate "Exit Wall"
        print("\n✅ TEST: Simulating Virtual Wall Exit")
        cmd = {"type": "haptic_feedback", "force": 0.0, "active": False}
        with open(cmd_file, 'w') as f:
            json.dump(cmd, f)
            
        time.sleep(1)
        output = read_bridge_output()
        if output: print(f"[Bridge Output]\n{output}")
        
        # 5. Check Status File
        if os.path.exists(status_file):
            with open(status_file, 'r') as f:
                status = json.load(f)
            print(f"\n📊 Current Status from Bridge: {status}")
            print("✅ SUCCESS: Bridge is writing status updates")
        else:
            print("\n❌ FAILURE: Bridge is NOT writing status file")
            
    finally:
        print("\n🛑 Stopping Bridge...")
        bridge_process.terminate()
        bridge_process.wait()

if __name__ == "__main__":
    test_integration()
