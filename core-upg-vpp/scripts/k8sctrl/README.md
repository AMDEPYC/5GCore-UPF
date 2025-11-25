# Kubernetes UPF Control Scripts (`k8sctrl`)

This directory contains automation scripts used to discover, configure, launch, and debug User Plane Function (UPF) pods inside Kubernetes.
These tools integrate with Kubernetes Power Manager (KPM) to fetch CPU and PCI resource data, and they orchestrate multi-pod UPF deployments efficiently.

---

## 📂 Directory Structure
```
scripts/k8sctrl/
│
├── k8s_upf_runner.py         # Main orchestrator for UPF deployment lifecycle
├── k8s_pod_app_launcher.py   # Extract CPU/PCI info from KPM + invoke launch_upf.sh
├── pod-launch.py             # Per-pod launcher invoked by runner
├── pod_cpu_network_info.sh   # Dump CPU, PCIe, MAC details for a pod
├── pod_network_info.sh       # Dump pod networking details
└── run_upf.py                # Optional wrapper script
```

---

## 1️⃣ `k8s_upf_runner.py` — Main UPF Pod Orchestrator

This script:
- Lists all pods in a namespace
- Selects those with label `app=<deployment_name>`
- Ensures pod container readiness
- Assigns each pod an incremental index
- Launches `pod-launch.py` per pod

### **Usage**
```
./k8s_upf_runner.py <namespace> <deployment_name> <mode> <pmgmt>
```

### **Arguments**
- `namespace`: Kubernetes namespace to use
- `deployment_name`: Value of `app=` label
- `mode`: `generate`, `launch`, or `both`
- `pmgmt`: Enable power management (`on`/`off`)

### **Execution Flow**
```
k8s_upf_runner.py
│
├─ kubectl get pods -n <namespace>
├─ filter: labels.app == <deployment_name>
├─ filter: pod ready
└─ call pod-launch.py <namespace> <pod_name> <pod_idx> <mode> <pmgmt>
```

---

## 2️⃣ `k8s_pod_app_launcher.py` — CPU/PCI Extractor & In-Pod Launcher

This script interacts with KPM (`powernodes` CRD) to fetch CPU and PCI resource assignments.

### Responsibilities:
- Read `powernodes` CRD
- Recursively find pod-specific container info
- Extract:
  - Exclusive CPU list
  - CPU ranges split into two NUMA groups
  - PCI addresses via `kubectl describe pod`
- Build arguments required for `/5gupf/scripts/launch_upf.sh`
- Execute UPF launch inside pod using `kubectl exec`

### **Usage**
```
./k8s_pod_app_launcher.py <namespace> <pod_name> <pod_idx> <mode> <pmgmt>
```

### Example executed inside pod:
```
kubectl exec <pod> -n <namespace> -- \
  /5gupf/scripts/launch_upf.sh <pod_idx> \
  <PCI1> <PCI2> <CPU_RANGE1> <CPU_RANGE2> <SINGLE_CPU> <NUM_SESSIONS> \
  <pmgmt> <mode>
```

---

## 3️⃣ `pod-launch.py`

Called internally by `k8s_upf_runner.py`.

Expected functions:
- Interact with `k8s_pod_app_launcher.py`
- Manage pod resource preparation
- Pass parameters to launch logic

---

## 4️⃣ `pod_cpu_network_info.sh`

Utility script for hardware-level debugging.

### Extracts:
- CPU topology and cpusets
- PCI addresses
- MAC addresses

### **Usage**
```
./pod_cpu_network_info.sh <pod> <namespace>
```

---

## 5️⃣ `pod_network_info.sh`

Collects network-related details:
- Interfaces
- IPs and routes
- Multus/SRIOV NICs
- VF mappings

### **Usage**
```
./pod_network_info.sh <pod> <namespace>
```

---

## 🔧 Dependencies

| Script | Dependencies |
|--------|--------------|
| All Python scripts | Python3, kubectl |
| `k8s_pod_app_launcher.py` | KPM CRDs (`powernodes`) |
| `pod_cpu_network_info.sh` | jq, pciutils, lscpu |
| `pod_network_info.sh` | jq, iproute2 |

---

## 🔄 End-to-End Launch Flow
```
k8s_upf_runner.py
│
└── pod-launch.py (per pod)
      │
      └── k8s_pod_app_launcher.py
            │
            ├─ Get CPU list from powernodes CRD
            ├─ Parse PCI addresses from kubectl describe
            ├─ Construct launch_upf.sh arguments
            └─ kubectl exec into pod → start UPF
```

---

## 📝 Notes
- Pods must contain the label: `app=<deployment_name>`
- KPM must be installed (`power-manager` namespace)
- UPF pods must contain annotation exposing PCI resources

---
