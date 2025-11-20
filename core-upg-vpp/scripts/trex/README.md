⚙️  1. Prerequisites
     * DPDK-compatible NICs (Intel, Mellanox, AMD)
     * Hugepages configured (e.g., echo 2048 > /proc/sys/vm/nr_hugepages)
     * Python 3.8+ and virtual environment
     * Required Python packages:
       - scapy==2.4.3
       - six==1.17.0

🧱 2. TRex Installation
     * mkdir -p /opt/trex-v3.07
     * cd /opt/sivapt/trex-v3.07
# Extract TRex tarball here

     * python3 -m venv /opt/trex-venv38
     * source /opt/trex-venv38/bin/activate
     * pip install scapy==2.4.3 six

🧩 3. Launching TRex
     * sudo -E PYTHON3=/opt/trex-venv38/bin/python3 \
            PYTHONPATH=/opt/trex-venv38/lib/python3.8/site-packages \
            ./t-rex-64 -i -c 16
       -i → Interactive TUI mode 
       -c 16 → Number of CPU cores assigned

     * trex-console (in other terminal)
       ./trex-console
       tui

🧪 4. Running Traffic in TUI
     * tui>start -p 1 -f stl/32udp_n6.py -m 550 
     * tui>start -p 0 -f stl/32gtpu_n3.py -m 600

📊 5. Monitoring and Control
     * stats          - Show TX/RX rates, drops, and CPU utilization
     * stop           - Stop all traffic
     * stop -p <port> - Stop traffic on specific port
     * clear          - Reset counters
     * quit           - Exit TUI 	 	

⚖️  6. Adjusting Multipliers (-m)
     * Target rate per port=Packets per stream × Number of streams × m
       Guidelines:
       - Check NIC line rate (e.g., 200 Gbps).
       - Calculate total packets per second for all streams:
         total_pps = pps_per_stream * number_of_streams * m
       - Adjust -m to stay within link bandwidth and avoid CPU saturation.
       - Monitor CPU util and Drop % in TUI to tune further.

 🛠 7. Utilities and Tips
      * Use start with duration for automated runs:
        tui>start -p 0 -f stl/32gtpu_n3.py -m 600 -d 60
