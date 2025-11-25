#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
BLUE='\033[1;34m'
NC='\033[0m'

# Header
printf "\n${YELLOW}%-40s %-12s %-16s %-17s${NC}\n" "   NS / POD_ID" "INTERFACE" "PCI_ADDR" " MAC_ADDR"
printf "${YELLOW}%-40s %-12s %-16s %-17s${NC}\n" "----------------------------------------" "------------" "----------------" "-----------------"

for ns in $(kubectl get ns --no-headers | awk '{print $1}'); do
  for pod in $(kubectl get pods -n "$ns" --no-headers 2>/dev/null | awk '{print $1}'); do

    net_info=$(kubectl get pod "$pod" -n "$ns" \
        -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}' 2>/dev/null)

    [[ -z "$net_info" ]] && continue

    #
    # Detect whether annotation is escaped JSON string or raw JSON
    #
    if [[ "$net_info" == \"* ]]; then
        net_json=$(printf "%s" "$net_info" | jq -r 'fromjson')
    else
        net_json="$net_info"
    fi

    echo "$net_json" >> /tmp/dump.txt

    echo "$net_json" | jq -c -r --arg pod "${ns}/${pod}" '
      .[] |
      [$pod,
       .interface // "N/A",
       (.["device-info"].pci["pci-address"] // "N/A"),
       .mac // "N/A"
      ] | @tsv' \
    | while IFS=$'\t' read -r pod_id iface pci mac; do
        printf "${CYAN}%-40s${NC} ${GREEN}%-12s${NC} ${MAGENTA}%-16s${NC} ${BLUE}%-17s${NC}\n" \
          "$pod_id" "$iface" "$pci" "$mac"
        #printf "%-40s %-12s %-16s %-17s\n" \
        #  "$pod_id" "$iface" "$pci" "$mac"
      done

  done
done

echo ""
