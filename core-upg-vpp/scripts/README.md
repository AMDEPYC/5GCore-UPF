# UPF Traffic & PFCP Simulation Script

This script automates the generation of session and VPP configuration for UPF testing, and optionally launches VPP-UPF along with PFCP simulation.

---

## 📄 Overview

The script performs **two main functions**:

1. **Generate configuration**
   - PFCP session configuration
   - UPF VPP configuration
   - VPP startup config for N3/N6 ports and worker cores

2. **Launch services**
   - Starts VPP-UPF for the given pod
   - Launches PFCP simulation (`smf_pfcp.sh`)

You can run either step individually or both together.

---

## ⚙️ 1. Prerequisites

- Linux server with VPP and PFCP simulation scripts installed (`/5gupf/scripts/...`)  
- Python 3.8+ (for session generation)  
- VPP installed and configured for DPDK/NIC usage  
- Required permissions to run scripts (`sudo` recommended)

---

## 🧱 2. Script Location

Download the 5GUPF software in a convenient path (e.g., `/opt/5GUPF`).

Ensure it is **executable**:
```bash
chmod +x /opt/5GUPF/core-upg-vpp/scripts/launch_upf.sh
```

--- 

## 🛠 3. Usage

sudo ./launch_upf.sh <pod_id> <n3_pci_addr> <n6_pci_addr> <n3_workers> <n6_workers> <main_core> <num_sess> <pmd_mgmt_on> <mode>

Arguments
Argument	Description	Default
pod_id	Pod identifier for the UPF instance	0
n3_pci_addr	PCI address for N3 interface	0000:41:00.0
n6_pci_addr	PCI address for N6 interface	0000:41:00.1
n3_workers	Worker core range for N3	8-15
n6_workers	Worker core range for N6	16-23
main_core	Main control core for VPP	1
num_sess	Number of PFCP sessions to generate	64
pmd_mgmt_on	Enable/disable PMD management (on/off)	off
mode	Operation mode: generate, launch, or both	both

Example Usage
1. Generate configuration only
sudo ./launch_upf.sh 0 0000:41:00.0 0000:41:00.1 8-15 16-23 1 64 off generate

2. Launch VPP-UPF & PFCP simulation only
sudo ./launch_upf.sh 0 0000:41:00.0 0000:41:00.1 8-15 16-23 1 64 off launch

3. Generate configuration and launch services
sudo ./launch_upf.sh 0 0000:41:00.0 0000:41:00.1 8-15 16-23 1 64 off both

--- 

🧩 4. How the Script Works

4.1 Generate Config (generate_config)

Calls the Python script to generate PFCP sessions:

/5gupf/scripts/pfcp_sim/session_gen.py <num_sess>


Generates UPF VPP configuration:

/5gupf/scripts/vpp/vpp_upf_config.sh generate <pod_id>


Creates VPP startup configuration for PCI devices and worker cores:

/5gupf/scripts/vpp/generate_vpp_conf.sh <pod_id> <n3_pci> <n6_pci> <n3_workers> <n6_workers> <main_core> <pmd_mgmt>

4.2 Launch Services (launch_test)

Starts the VPP-UPF instance:

/5gupf/scripts/vpp/launch_vpp.sh <pod_id>


Starts PFCP simulation to communicate with UPF:

/5gupf/scripts/pfcp_sim/smf_pfcp.sh

---

📊 5. Notes & Tips

Sleep intervals in the script allow each stage to complete before the next starts.

Mode selection allows flexibility for different testing workflows.

Ensure the PCI addresses match the system’s N3/N6 network interfaces.

Monitor logs for PFCP connectivity and VPP interface state.

---

✅ 6. Summary

Mode generate → Only creates configuration files.

Mode launch → Only launches VPP-UPF and PFCP simulation.

Mode both → Performs full workflow: generate + launch.

---

🔄 7. Workflow Diagram
        +----------------------+
        | Generate Config      |
        | - VPP UPF config     |
        | - Worker/core config |
        | - PFCP sessions      |
        +----------+-----------+
                   |
                   v
        +----------------------+
        | Launch VPP-UPF       |
        | - Start VPP instance |
        | - Configure N3/N6    |
        +----------+-----------+
                   |
                   v
        +----------------------+
        | Start PFCP Simulation|
        | - SMF communicates   |
        |   with UPF           |
        +----------+-----------+
                   |
                   v
        +----------------------+
        | Traffic Test Ready   |
        | - N3 GTP-U           |
        | - N6 UDP             |
        +----------------------+
