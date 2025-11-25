#!/usr/bin/env python3
import subprocess
import json
import sys

if len(sys.argv) != 5:
    print(f"Usage: {sys.argv[0]} <namespace> <deployment_name> <mode> <pmgmt>")
    sys.exit(1)

namespace = sys.argv[1]
deployment_name = sys.argv[2]
mode = sys.argv[3]
pmgmt = sys.argv[4]

# Get all pods in JSON
kubectl_cmd = ["kubectl", "get", "pods", "-n", namespace, "-o", "json"]
result = subprocess.run(kubectl_cmd, capture_output=True, text=True)
pods_json = json.loads(result.stdout)

processes = []  # list to keep track of all Popen objects
pod_idx = 0

for pod in pods_json["items"]:
    pod_name = pod["metadata"]["name"]
    labels = pod["metadata"].get("labels", {})
    pod_phase = pod["status"].get("phase")
    container_statuses = pod["status"].get("containerStatuses", [])
    ready_status = pod_phase == "Running" and all(cs.get("ready", False) for cs in container_statuses)

    print(f"Pod: {pod_name}, Phase: {pod_phase}, Ready: {ready_status}, Labels: {labels}")

    # Only run for pods belonging to the deployment and are ready
    if labels.get("app") == deployment_name and ready_status:
        print(f"Launching pod-launch.py for {pod_name} with index {pod_idx}")
        p = subprocess.Popen(["python3", "./pod-launch.py", namespace, pod_name, str(pod_idx), str(mode), str(pmgmt)]
						,stdout=subprocess.DEVNULL,
					    stderr=subprocess.DEVNULL
        				)
        processes.append(p)
        subprocess.run(["python3", "./pod-launch.py", namespace, pod_name, str(pod_idx), str(mode), str(pmgmt)])
        pod_idx += 1  # increment for next pod

for p in processes:
    p.wait()  # blocks until that process exits
