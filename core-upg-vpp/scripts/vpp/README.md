# VPP Startup Configuration Generator (`generate_vpp_conf.sh`)

This script automates the creation of **VPP startup configuration files** (`startup.conf`) for UPF instances.  
It allows specifying custom **PCI devices, worker cores, main core, and PMD monitoring** options.

---

## ⚙️ 1. Prerequisites

- Linux server with **VPP installed**
- Sudo privileges for writing `/etc/startup*.conf`
- Knowledge of PCI addresses and CPU core allocation for DPDK/UPF
- `/usr/local/lib/x86_64-linux-gnu/vpp_plugins` available for plugins

---

## 🧱 2. Script Purpose

- Create a **VPP startup configuration** file for a given POD/UPF instance
- Configure:
  - PCI devices for N3/N6
  - Worker cores for DPDK queues
  - Main core for VPP
  - Optional PMD monitoring
- Automatically backs up existing configuration
- Generates an auxiliary execution file (`upfdpdk<POD_ID>.txt`) for reference

---

## 🛠 3. Usage

```bash
sudo ./generate_vpp_conf.sh <pod_id> <pci_n3> <pci_n6> <workers_n3> <workers_n6> <main_core> <pmd_monitor>
```

 Argument	Description                                     Default
----------     -------------                                   ---------
pod_id	       POD_ID(config files)	                       (required)
pci_n3	       PCI address(N3 iface)	                       (required)
pci_n6	       PCI address(N6 iface)	                       (required)
workers_n3     Worker cores for N3 (comma-separated or range)  (required)
workers_n6     Worker cores for N6 (comma-separated or range)  (required)
main_core      Main core for VPP	                       (required)
pmd_monitor    Enable PMD monitoring (on/off)	                 off

```bash
sudo ./generate_vpp_conf.sh 0 0000:41:00.0 0000:41:00.1 8-15 16-23 1 on
```

Notes: Omitting the last on argument will disable PMD monitoring by default.
---

## 🧩 4. How It Works

 * Validate input arguments
 * Backup existing configuration
 * Normalize worker cores
 * Conditional PMD monitor
 (
