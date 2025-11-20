#!/bin/bash

#===================================================================
#  generate_vpp_conf.sh
#  Automates creation of VPP startup.conf with custom PCI and cores
#===================================================================
POD_ID=${1:-}
CONF_FILE="/etc/startup${POD_ID}.conf"
UPF_EXEC_FILE="/etc/upfdpdk${POD_ID}.txt"

#PCI addresses
PCI_N3=${2:-0000:41:00.0}
PCI_N6=${3:-0000:41:00.1}

#Worker core assignments
WORKERS_N3=${4:-8-15}
WORKERS_N6=${5:-16-23}
MAIN_CORE=${6:-1}

# PMD Management Monitor toggle (on/off)
PMD_MONITOR=${7:-off}  # default disabled

#=== Derived values ===
CORELIST_WORKERS="${WORKERS_N3},${WORKERS_N6}"

#=== Validate ===
echo "----------------------------------------"
echo "Generating VPP startup.conf with:"
echo " POD_ID = $POD_ID"
echo " PCI_N3 = $PCI_N3"
echo " PCI_N6 = $PCI_N6"
echo " WORKERS_N3 = $WORKERS_N3"
echo " WORKERS_N6 = $WORKERS_N6"
echo " MAIN_CORE = $MAIN_CORE"
echo " PMD_MONITOR = $PMD_MONITOR"
echo "----------------------------------------"

#=== Backup existing config ===
if [ -f "$CONF_FILE" ]; then
  echo "Backing up existing config to ${CONF_FILE}.bak"
  sudo cp "$CONF_FILE" "${CONF_FILE}.bak"
fi

#=== Normalize worker strings and count ===
# WORKERS_N3 and WORKERS_N6 may look like "2,3,4" or "5-8"
expand_worker_list() {
  local workers="$1"
  local expanded=()
  IFS=',' read -ra PARTS <<< "$workers"
  for part in "${PARTS[@]}"; do
    if [[ "$part" =~ ^[0-9]+-[0-9]+$ ]]; then
      start=${part%-*}
      end=${part#*-}
      for ((i=start; i<=end; i++)); do
        expanded+=("$i")
      done
    else
      expanded+=("$part")
    fi
  done
  echo "${expanded[@]}"
}

count_workers() {
  local workers_expanded
  workers_expanded=($(expand_worker_list "$1"))
  echo "${#workers_expanded[@]}"
}

NUM_RX_QUEUES_N3=$(count_workers "$WORKERS_N3")
NUM_RX_QUEUES_N6=$(count_workers "$WORKERS_N6")

echo " Calculated num-rx-queues:"
echo "   N3: $NUM_RX_QUEUES_N3"
echo "   N6: $NUM_RX_QUEUES_N6"
echo "----------------------------------------"

# Conditionally set PMD monitor line
if [[ "$PMD_MONITOR" =~ ^(on|enable|yes|true)$ ]]; then
  PMD_MONITOR_LINE="  pmd-mgmt monitor"
else
  PMD_MONITOR_LINE=""
fi

#=== Write new config ===
sudo tee "$CONF_FILE" > /dev/null <<EOF
unix {
  log /tmp/vpp$POD_ID.log
  full-coredump
  gid vpp
  cli-listen /run/vpp/cli$POD_ID.sock
  exec $UPF_EXEC_FILE
}

dpdk {
  dev default {
    num-rx-desc 2048
    num-tx-desc 2048
  }
  dev $PCI_N3 {
    num-rx-queues $NUM_RX_QUEUES_N3
    name n3
    workers $WORKERS_N3
    rss-queues 0-$((NUM_RX_QUEUES_N3 - 1))
  }
  dev $PCI_N6 {
    num-rx-queues $NUM_RX_QUEUES_N6
    name n6
    workers $WORKERS_N6
    rss-queues 0-$((NUM_RX_QUEUES_N6 - 1))
  }
  telemetry
${PMD_MONITOR_LINE}
  empty-polls 1
}

api-trace {
  on
}

cpu {
  main-core $MAIN_CORE
  corelist-workers $CORELIST_WORKERS
}

api-segment {
  gid vpp
}

plugins {
  path /usr/local/lib/x86_64-linux-gnu/vpp_plugins
  plugin dpdk_plugin.so { enable }
  plugin gtpu_plugin.so { disable }
  plugin upf_plugin.so { enable }
}
EOF

echo "✅ VPP startup.conf created successfully!"
echo " -> $CONF_FILE"
echo ""
echo "To start VPP with this config:"
echo " sudo vpp -c $CONF_FILE"
echo ""
echo "Example usage:"
echo " sudo ./generate_vpp_conf.sh 0 0000:41:00.0 0000:41:00.1 8-15 16-23 1 on"
echo ""
echo "If you omit the last 'on', PMD monitor will be disabled by default."
