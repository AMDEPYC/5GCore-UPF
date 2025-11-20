#!/bin/bash
# ============================================================
# Multus + SR-IOV Diagnostic Tool
# Author: GPT-5 (for Siva)
# ============================================================

NAMESPACE="kube-system"
NODE_NAME=$(kubectl get node -o wide | awk 'NR==2{print $1}')

echo "�� Multus + SR-IOV Diagnostic Summary"
echo "====================================="
echo "Node under test: $NODE_NAME"
echo

# --- 1. Check Multus DaemonSet pods ---
echo "🧩 Checking Multus DaemonSet status..."
kubectl get pods -n $NAMESPACE -l app=multus | tee /tmp/multus_pods.txt
echo

# --- 2. Check SR-IOV Device Plugin pods ---
echo "🧩 Checking SR-IOV Device Plugin status..."
kubectl get pods -n $NAMESPACE -l app=sriov-network-device-plugin | tee /tmp/sriov_pods.txt
echo

# --- 3. Describe node resources for SR-IOV ---
echo "🧠 Checking SR-IOV resource registration on node..."
kubectl describe node $NODE_NAME | grep -A4 -E "Capacity|Allocatable" | grep sriov || echo "⚠️  No SR-IOV resources registered on node."
echo

# --- 4. Verify CNI binaries ---
echo "🔎 Checking for key CNI binaries in /opt/cni/bin/ ..."
for bin in multus-shim sriov flannel host-local bridge; do
  if [ -f /opt/cni/bin/$bin ]; then
    echo "✅ $bin found"
  else
    echo "❌ $bin missing"
  fi
done
echo

# --- 5. Validate Multus CNI config ---
echo "📄 Inspecting /etc/cni/net.d for Multus and Flannel configs..."
ls -1 /etc/cni/net.d/
echo
grep -H '"type"' /etc/cni/net.d/*.conf /etc/cni/net.d/*.conflist 2>/dev/null | grep -E 'multus|flannel'
echo

# --- 6. List all NetworkAttachmentDefinitions ---
echo "🧩 Listing all NetworkAttachmentDefinitions..."
kubectl get net-attach-def -A | tee /tmp/nad_list.txt
echo

# --- 7. Validate each NAD JSON config ---
for nad in $(kubectl get net-attach-def -A -o jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}'); do
  ns=$(echo $nad | cut -d, -f1)
  name=$(echo $nad | cut -d, -f2)
  echo "➡️  Checking NAD: $ns/$name"
  kubectl get net-attach-def $name -n $ns -o jsonpath='{.spec.config}' | jq . >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "   ✅ JSON config valid"
  else
    echo "   ❌ JSON config invalid or malformed"
  fi
done
echo

# --- 8. Recent Multus logs ---
echo "🪵 Collecting recent Multus logs..."
kubectl logs -n $NAMESPACE -l app=multus --tail=50 | grep -E "error|panic|failed" || echo "✅ No immediate Multus errors detected"
echo

# --- 9. Check kubelet or dmesg for Multus crash traces ---
echo "🧾 Checking kubelet and kernel logs for Multus crashes..."
sudo journalctl -u kubelet | grep -i multus | tail -n 10
sudo dmesg | grep -i multus | tail -n 10
echo

echo "✅ Diagnostic summary complete."
echo "📂 Intermediate logs saved under /tmp/multus_*.txt"
echo "============================================================"
