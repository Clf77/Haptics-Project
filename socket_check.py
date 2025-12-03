import socket
import json
import time
import subprocess
import sys
import os

def test_socket_integration():
    print("🚀 Starting Socket Integration Test")
    
    # 1. Start Bridge Controller
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

    client_socket = None
    try:
        # Wait for server to start
        time.sleep(2)
        print(f"[Bridge Output]\n{read_bridge_output()}")
        
        # 2. Connect to Bridge
        print("\n🔗 Connecting to Bridge (localhost:5005)...")
        client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        client_socket.connect(('127.0.0.1', 5005))
        client_socket.setblocking(False)
        print("✅ Connected!")
        
        # 3. Send Command
        print("\n📤 Sending Status Request...")
        cmd = {"type": "status_request"}
        client_socket.sendall((json.dumps(cmd) + "\n").encode())
        
        # 4. Read Response
        print("📥 Waiting for response...")
        start_time = time.time()
        response_received = False
        
        while time.time() - start_time < 2.0:
            try:
                readable, _, _ = select.select([client_socket], [], [], 0.1)
                if readable:
                    data = client_socket.recv(4096)
                    if data:
                        print(f"✅ Received: {data.decode().strip()}")
                        response_received = True
                        break
            except Exception as e:
                pass
            
            # Print bridge output while waiting
            out = read_bridge_output()
            if out: print(f"[Bridge Log] {out.strip()}")
            
        if response_received:
            print("\n✅ SUCCESS: TCP Communication Verified")
        else:
            print("\n❌ FAILURE: No response received")

    except Exception as e:
        print(f"\n❌ TEST FAILED: {e}")
    finally:
        if client_socket:
            client_socket.close()
        print("\n🛑 Stopping Bridge...")
        bridge_process.terminate()
        bridge_process.wait()

if __name__ == "__main__":
    import select # Import here to be safe
    test_socket_integration()
