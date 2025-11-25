#!/usr/bin/env python3
import json
import subprocess
import sys

def find_container_by_pod(obj, pod_name):
    """Recursively search JSON for a container with the given pod_name."""
    if isinstance(obj, dict):
        if obj.get("pod") == pod_name:
            return obj
        for v in obj.values():
            result = find_container_by_pod(v, pod_name)
            if result:
                return result
    elif isinstance(obj, list):
        for item in obj:
            result = find_container_by_pod(item, pod_name)
            if result:
                return result
    return None

def get_pod_resources(pod_name, namespace="default", powernode="epycpwr02"):
    # 1. Get powernode JSON
    cmd = ["kubectl", "get", "powernodes", powernode, "-n", "power-manager", "-o", "json"]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    data = json.loads(result.stdout)

    # 2. Find container with the given pod
    container_info = find_container_by_pod(data, pod_name)
    if not container_info:
        raise RuntimeError(f"No container found for pod {pod_name}")

    # 3. Get exclusive CPUs
    exclusive_cpus = container_info.get("exclusiveCpus", [])
    # Split into two NUMA nodes (example: first half / second half)
    half = len(exclusive_cpus) // 2
    first_half = exclusive_cpus[:half]
    next_half = exclusive_cpus[half:]
    cpu_range1 = f"{first_half[1]}-{first_half[-1]}"
    cpu_range2 = f"{next_half[1]}-{next_half[-1]}"
    single_cpu = exclusive_cpus[0]  # example: first CPU
    num_sessions = 64  # as in your launch_upf.sh example

    # 4. Get PCI addresses via `kubectl describe pod`
    cmd2 = ["kubectl", "describe", "pod", pod_name, "-n", namespace]
    result2 = subprocess.run(cmd2, capture_output=True, text=True, check=True)
    pci_addresses = []
    for line in result2.stdout.splitlines():
        line = line.strip()
        if '"pci-address":' in line:
            addr = line.split('"')[3]
            pci_addresses.append(addr)
    if len(pci_addresses) < 2:
        raise RuntimeError(f"Expected at least 2 PCI addresses for pod {pod_name}")

    # 5. Return in order needed for launch_upf.sh
    return [pci_addresses[0], pci_addresses[1], cpu_range1, cpu_range2, single_cpu, num_sessions]

def main():
    if len(sys.argv) != 6:
        print(f"Usage: {sys.argv[0]} <namespace> <pod_name> <pod_idx> <mode> <pmgmt>")
        print(f" Mode: generate | launch | both")
        print(f" PMgmt: off | on")
        sys.exit(1)

    namespace = sys.argv[1]
    pod_name = sys.argv[2]
    pod_idx = sys.argv[3]
    mode = sys.argv[4]
    power_mgmt = sys.argv[5]

    args = get_pod_resources(pod_name)
    cmd = [
        "kubectl", "exec", pod_name, "-n", namespace, "--",
        "/5gupf/scripts/launch_upf.sh", str(pod_idx),
    ] + list(map(str, args)) + [power_mgmt] + [mode]
 
    print("Executing:", " ".join(cmd))
    subprocess.run(cmd)

if __name__ == "__main__":
    main()
