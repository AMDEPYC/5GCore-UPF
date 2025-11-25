#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
BLUE='\033[1;34m'
NC='\033[0m'

# Header
printf "\n${YELLOW}%-40s %-12s %-20s %-17s %-18s %-12s${NC}\n" \
    "     NS / POD_ID" "INTERFACE" "PCI_ADDR" "MAC_ADDR" "EXCLUSIVE_CPUS" "POWER_PROFILE"
printf "${YELLOW}%-40s %-12s %-16s %-17s %-20s %-30s${NC}\n" \
    "------------------------------------" "------------" "----------------" "------------------" "--------------------" "-------------------"

# Get powernodes JSON
powernodes_json=$(kubectl get powernodes -n power-manager -o json)

# Build a mapping: pod/namespace -> exclusive CPUs + profile/workload
declare -A pod_cpu_map
declare -A pod_profile_map

cpus_to_ranges() {
    local cpus=($(echo "$1" | tr ',' ' '))
    local start end prev result=""
    for cpu in "${cpus[@]}"; do
        if [[ -z "$start" ]]; then
            start=$cpu
            prev=$cpu
        elif (( cpu == prev + 1 )); then
            prev=$cpu
        else
            if [[ $start == $prev ]]; then
                result+="$start,"
            else
                result+="$start-$prev,"
            fi
            start=$cpu
            prev=$cpu
        fi
    done
    # Append the last range
    if [[ -n "$start" ]]; then
        if [[ $start == $prev ]]; then
            result+="$start"
        else
            result+="$start-$prev"
        fi
    fi
    echo "$result"
}

# Loop through each PowerNode
while IFS= read -r container; do
    pod=$(echo "$container" | jq -r '.pod')
    ns=$(echo "$container" | jq -r '.namespace')
    cpus=$(echo "$container" | jq -r '.exclusiveCpus | join(",")')
    profile=$(echo "$container" | jq -r '.powerProfile')
    pod_key="${ns}/${pod}"
    cpus_range=$(cpus_to_ranges "$cpus")
    pod_cpu_map["$pod_key"]="$cpus_range"
    pod_profile_map["$pod_key"]="$profile"
done < <(echo "$powernodes_json" | jq -c '.items[].spec.powerContainers[]?')

# Loop through namespaces and pods
for ns in $(kubectl get ns --no-headers | awk '{print $1}'); do
  for pod in $(kubectl get pods -n "$ns" --no-headers 2>/dev/null | awk '{print $1}'); do

    # Get network annotation
    net_info=$(kubectl get pod "$pod" -n "$ns" \
        -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}' 2>/dev/null)
    [[ -z "$net_info" ]] && continue

    # Decode JSON string if needed
    if [[ "$net_info" == \"* ]]; then
        net_json=$(printf "%s" "$net_info" | jq -r 'fromjson')
    else
        net_json="$net_info"
    fi

    # Fetch exclusive CPUs and profile from the mapping
    pod_key="${ns}/${pod}"
    exclusive_cpus="${pod_cpu_map[$pod_key]:-N/A}"
    profile_workload="${pod_profile_map[$pod_key]:-N/A}"

    # Loop over network interfaces
    echo "$net_json" | jq -c -r --arg pod "$pod_key" '
      .[] |
      [$pod,
       .interface // "N/A",
       (.["device-info"].pci["pci-address"] // "N/A"),
       .mac // "N/A"
      ] | @tsv' \
    | while IFS=$'\t' read -r pod_id iface pci mac; do
        printf "${CYAN}%-40s${NC} ${GREEN}%-12s${NC} ${MAGENTA}%-16s${NC} ${BLUE}%-20s${NC} ${YELLOW}%-20s${NC} ${RED}%-15s${NC}\n" \
          "$pod_id" "$iface" "$pci" "$mac" "$exclusive_cpus" "$profile_workload"
      done

  done
done

echo ""

