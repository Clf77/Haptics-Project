import socket
import time
import json
import statistics

HOST = '127.0.0.1'
PORT = 5005

def test_latency():
    print(f"Connecting to {HOST}:{PORT}...")
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        s.connect((HOST, PORT))
        print("Connected.")
    except ConnectionRefusedError:
        print("Connection refused. Is the bridge running?")
        return

    latencies = []
    iterations = 100

    print(f"Running {iterations} ping-pong tests...")
    
    # Clear initial buffer
    s.setblocking(0)
    try:
        while s.recv(4096): pass
    except:
        pass
    s.setblocking(1)

    for i in range(iterations):
        # Send status request
        cmd = {"type": "status_request", "id": i}
        msg = json.dumps(cmd) + "\n"
        
        start_time = time.perf_counter()
        s.sendall(msg.encode())
        
        # Wait for response
        try:
            data = s.recv(4096)
            end_time = time.perf_counter()
            
            if not data:
                print("Server disconnected.")
                break
                
            rtt = (end_time - start_time) * 1000 # ms
            latencies.append(rtt)
            
            # print(f"RTT: {rtt:.3f} ms")
            
        except socket.timeout:
            print("Timeout waiting for response")
            break
            
        time.sleep(0.01) # Small delay between requests

    s.close()

    if latencies:
        avg = statistics.mean(latencies)
        min_lat = min(latencies)
        max_lat = max(latencies)
        jitter = statistics.stdev(latencies) if len(latencies) > 1 else 0
        
        print("\n--- Latency Statistics ---")
        print(f"Samples: {len(latencies)}")
        print(f"Average: {avg:.3f} ms")
        print(f"Min:     {min_lat:.3f} ms")
        print(f"Max:     {max_lat:.3f} ms")
        print(f"Jitter:  {jitter:.3f} ms")
    else:
        print("No data collected.")

if __name__ == "__main__":
    test_latency()
