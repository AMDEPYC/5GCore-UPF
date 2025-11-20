# UPF Traffic & PFCP Simulation Scripts

This repository contains scripts to generate PFCP sessions, launch UPF (VPP-based), and run PFCP simulations for testing.  
The workflow includes **session generation → VPP launch → PFCP client simulation → traffic monitoring**.

---

## ⚙️ 1. Prerequisites

- Linux server with VPP installed
- Python 3.6+ and `PyYAML` package
```bash
pip install pyyaml
```
---

## 🧱 2. Scripts Overview

Script	         Purpose
-------         ---------
session_gen.py	 Generates PFCP session YAML file with uplink/downlink flows, PDRs, FARs, and URRs
smf_pfcp.sh	 Launches PFCP client to communicate with UPF, monitors sessions and interfaces
upf_run.sh	 Generates configuration and launches VPP-UPF + PFCP workflow
---

## 🛠 3. PFCP Session Generator (`session_gen.py`)

This Python script generates PFCP session configuration for UPF testing.  
It creates multiple UE sessions with uplink and downlink flows and outputs them in YAML format.

```bash
./session_gen.py [num_sessions] [output_file]
```
 Argument	Description  	                     Default
----------     -------------                        ----------
num_sessions	Number of UE sessions to generate      64
output_file	Name of the YAML file	            pfcp_sessions_with_urr.yaml

```bash
./session_gen.py 128 my_pfcp_sessions.yaml
```
---

### 🧩 3.1. How It Works

* The script sets default values:
  - num_sessions = 64
  - pfcp_session = pfcp_sessions_with_urr.yaml
  - Base UE IP: 10.10.10.10
  - UPF IP: 192.168.72.201
  - Base TEID: UL=1234, DL=4321
* Iterates for each session i:
  - Generates UE IP: 10+i.10+i.10+i.10+i
  - Assigns SEID, PDR ID, FAR ID, URR ID for uplink/downlink
* Creates uplink session with:
  - Source interface: Access
  - Destination interface for FAR: SGiLAN
  - Outer header removal: GTPU/UDP/IPv4
  - URR configured for volume/duration measurement and reporting
  Creates downlink session with:
  - Source interface: SGiLAN
  - Destination interface for FAR: Access
  - Outer header creation: GTPU/UDP/IPv4
  - SDF filter to match UE IP
  - URR configured similarly for measurement and reporting
* All sessions are stored in a list and dumped into a YAML file.
  Writes the session configuration to a YAML file (default or custom).
--- 

### 📄 3.2. Output Format

The generated YAML contains entries like:

- seid: 0
  pdrs:
    - pdrID: 0
      precedence: 0
      pdi:
        sourceInterface: Access
        localFTEID:
          teid: 1234
          ip4: 192.168.72.201
        networkInstance: access
        ueIPAddress:
          isDestination: False
          ip4: 10.10.10.10
  fars:
    - farID: 10
  urrs:
    - urrID: 100


Each UE session has uplink and downlink PDRs, FARs, and URRs.

TEIDs, SEIDs, and IPs are automatically incremented per session.
---

## 🛠 4. PFCP Simulator (`smf_pfcp.sh`)

This script runs a **PFCP client simulator** to interact with a UPF.  
It automatically generates PFCP sessions, launches the client, monitors
interface and session health, and restarts the client if necessary.

### ⚙️ 4.1. Prerequisites

- Linux server with VPP installed and running
- Python 3.6+ and `session_gen.py` for PFCP session generation
- Network interface configured for PFCP (default `n4`)
- Sudo privileges for managing network interfaces and UDP ports

---

## 🧱 4.2. How it works

- Generate PFCP session YAML via `session_gen.py`
- Bring up the PFCP interface (`IFACE`) with a local IP
- Launch `pfcpclient` to communicate with remote UPF PFCP endpoint
- Monitor interface and UPF session health
- Automatically restart PFCP client if interface down or sessions missing
- Log all actions to `/var/log/pfcpclient_monitor.log`

---

## 🛠 4.3. Usage
```bash
sudo ./smf_pfcp.sh [num_sessions]
```
**Configurable variables**

 Variable	 Default	               Description 
-------------   ---------             ----------------
NUM_SESSIONS	 64 	              Number of PFCP sessions
IFACE	         n4	              Interface for PFCP client
LOCAL_IP	 192.168.70.1	      Local PFCP IP
REMOTE_IP	 192.168.70.201	      UPF PFCP IP
PFCP_SESSIONS	 /5gupf/scripts/pfcp_sim/pfcp_sessions_with_urr.yaml	YAML session file
PFCP_PORT	 10000	              Local PFCP client port
PFCP_REMOTE_PORT 8805	              Remote PFCP server port
SLEEP_INTERVAL	 15	              Seconds between checks

```bash
sudo ./smf_pfcp.sh 64
```
---
 
## 🧩 5. Workflow Diagram

```text
        +----------------------+
        | session_gen.py       |
        | Generate PFCP YAML   |
        +----------+-----------+
                   |
                   v
        +----------------------+
        | Launch VPP-UPF       |
        | Configure N3/N6      |
        +----------+-----------+
                   |
                   v
        +----------------------+
        | smf_pfcp.sh          |
        | Start PFCP client    |
        | Monitor sessions     |
        +----------+-----------+
                   |
                   v
        +----------------------+
        | Traffic Test Ready   |
        | UL/DL sessions active|
        +----------------------+
```
---

## ✅ 6. Notes & Tips

The script is idempotent: running multiple times overwrites the output file.
Ensure num_sessions is within reasonable limits for your UPF/CPU resources.
Can be integrated into automated UPF testing workflows, e.g., before launching VPP-UPF.


