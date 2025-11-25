# UPF Deployment on Kubernetes (VPP/DPDK + SR-IOV + AMD EPYC Power Tuning)

This repository contains a Kubernetes deployment of a high-performance **User Plane Function (UPF)** based on **VPP (Vector Packet Processing)** and **DPDK**.
It is designed for 5G Core networks requiring low latency, high throughput, SR-IOV acceleration, and NUMA-aware performance on **AMD EPYC CPU** platforms.

---

## 📌 Features

- VPP/DPDK dataplane
- SR-IOV VF passthrough for N3 & N6 user-plane interfaces
- 1Gi HugePages for DPDK memory
- NUMA-aware CPU pinning
- VFIO device passthrough
- Multus CNI for attaching multiple networks
- Power/performance tuning via vendor resource:
  `power.amdepyc.com/performance`
- Designed for 5G UPF workloads

---

## 📁 Manifest Location

The main deployment file:

```
core-upg-vpp/manifests/upf_deployment.yaml
```

---

## 1. Architecture Overview

The UPF pod includes:

- **VPP/DPDK** engine for packet processing
- SR-IOV virtual functions mapped to the pod via Multus:
  - `n3-net` — Access/GNB interface
  - `n6-net` — DN/Internet interface
- **Privileged container** to allow PCI and driver operations
- **NUMA-aware scheduling** using topology hints and CPU manager
- **HugePages** for VPP packet memory pools
- **AMD EPYC CPU performance tuning** using extended resources

---

## 2. Prerequisites

### Cluster-Level

Enable CPU Manager & Topology Manager on worker nodes:

```yaml
cpuManagerPolicy: static
topologyManagerPolicy: single-numa-node
```

### Node-Level

- AMD EPYC processor
- Allocate hugepages:
  ```bash
  echo 4 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
  ```
- SR-IOV NIC (e.g., Mellanox ConnectX)
- DPDK-compatible VF drivers (vfio-pci)

### Software

- Kubernetes 1.25+
- SR-IOV Network Device Plugin
- Multus CNI
- Vendor-specific power tuning plugin exposing:
  `power.amdepyc.com/performance`

---

## 3. SR-IOV Network Attachments

Your UPF relies on two SR-IOV networks configured via Multus:

- `sriov-n3-net`
- `sriov-n6-net`

These must exist as `NetworkAttachmentDefinition` objects.

Example:

```yaml
k8s.v1.cni.cncf.io/networks: |
  [
    { "name": "sriov-n3-net", "interface": "n3-net" },
    { "name": "sriov-n6-net", "interface": "n6-net" }
  ]
```

---

## 4. AMD EPYC Power Tuning

### 4.1 What is `power.amdepyc.com/performance`?

A custom device plugin exposes this resource to allow UPF pods to request CPU cores in a high-performance mode.

**When requested**, the plugin may:

- Enable `performance` frequency governor
- Disable deep C-states
- Configure CPPC preferred cores
- Enable deterministic turbo
- Pin the workload to cores on the selected NUMA node
- Ensure stable throughput and low jitter for DPDK workloads

### 4.2 How UPF Requests It

```yaml
resources:
  requests:
    power.amdepyc.com/performance: "16"
  limits:
    power.amdepyc.com/performance: "16"
```

This reserves ~16 power-optimized cores for VPP.

---

## 5. NUMA, CPU Pinning & HugePages

### NUMA Hints

```yaml
topology.kubernetes.io/numa-node: "1"
```

This hints the scheduler to prefer NUMA node 1.

### CPU Pinning

With CPU Manager in `static` mode, requesting:

```
cpu: "16"
```

guarantees **16 exclusive pinned CPUs** for the pod.

### HugePages

UPF requires:

```
hugepages-1Gi: "4Gi"
```

Ensure the node has enough 1Gi pages preallocated.

---

## 6. Deploying the UPF

Apply the manifest:

```bash
kubectl apply -f core-upg-vpp/manifests/upf_deployment.yaml
```

Check pod status:

```bash
kubectl get pods -o wide
```

### Verify SR-IOV NICs:

```bash
kubectl exec -it <upf-pod> -- ip link
```

### Verify hugepages:

```bash
kubectl exec -it <upf-pod> -- grep Huge /proc/meminfo
```

### Verify CPU pinning:

```bash
kubectl exec -it <upf-pod> -- taskset -pc 1
```

### Verify AMD tuning (optional):

```bash
kubectl exec -it <upf-pod> -- cpupower frequency-info
```

---

## 7. Notes on Replicas

Your deployment uses:

```
replicas: 14
```

⚠ **UPF replicas cannot all run on one node**.

Each pod consumes:

- 16 CPUs
- 4Gi 1Gi HugePages
- 2 SR-IOV VFs

Your node(s) must have sufficient resources.

If deploying UPF per-node, prefer a **DaemonSet**.

---

## 8. Security Considerations

UPF container runs in **privileged mode** with `ALL` capabilities:

```yaml
privileged: true
capabilities:
  add: ["ALL"]
```

Required for:

- VFIO PCI binding
- Accessing `/sys/bus/pci/*`
- Managing DPDK memory
- Loading/unloading drivers

⚠ Use **dedicated, isolated nodes** for UPF workloads.

---
