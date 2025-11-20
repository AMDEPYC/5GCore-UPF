#!/bin/bash

#===========================================================
#    vpp_upf_config.sh
#  Generate or apply VPP UPF configuration
#===========================================================

set -e

#=== User-configurable variables ===
POD_ID=${2:-}
VPP_SOCK="/run/vpp/cli${POD_ID}.sock"
OUTPUT_FILE="/etc/upfdpdk${POD_ID}.txt"

cmds=(
  "ip table add 1"
  "ip6 table add 1"
  "ip table add 2"
  "ip6 table add 2"

  "set interface mtu 1500 n3"
  "set interface ip table n3 1"
  "set interface ip address n3 192.168.72.201/24"
  "set int promiscuous on n3"
  "set interface state n3 up"

  "create tap id 1 hw-addr 10:11:12:13:14:15 host-if-name n4"
  "set interface mtu 1500 tap1"
  "set interface ip table tap1 0"
  "set interface ip address tap1 192.168.70.201/24"
  "set interface state tap1 up"

  "set interface mtu 1500 n6"
  "set interface ip table n6 1"
  "set interface ip address n6 192.168.73.201/24"
  "set int promiscuous on n6"
  "set interface state n6 up"

  "ip route add 0.0.0.0/0 table 0 via 192.168.70.1 tap1"
  "ip route add 0.0.0.0/0 table 1 via 192.168.72.1 n6"
  "set ip neighbor n3 192.168.72.1 00:01:02:03:04:05 static"
  "set ip neighbor n6 192.168.73.1 00:11:22:33:44:55 static"

  "upf pfcp endpoint ip 192.168.70.201 vrf 0"
  "upf node-id fqdn vpp-upf.node.5gcn.mnc95.mcc208.3gppnetwork.org"
  "upf nwi name access vrf 1"
  "upf nwi name sgi vrf 1"
  "upf specification release 16"
  "upf gtpu endpoint ip 192.168.72.201 nwi access teid 0x000004d2/1"
)

usage() {
  echo "Usage: $0 [generate|apply]"
  echo
  echo " generate - write all commands to $OUTPUT_FILE"
  echo " apply - apply configuration directly via vppctl -s $VPP_SOCK"
  exit 1
}

MODE=$1
if [[ -z "$MODE" ]]; then
  usage
fi

if [[ "$MODE" == "generate" ]]; then
  echo "Generating VPP UPF configuration -> $OUTPUT_FILE"
  sudo mkdir -p "$(dirname "$OUTPUT_FILE")"
  {
    for c in "${cmds[@]}"; do
      echo "$c"
    done
  } | sudo tee "$OUTPUT_FILE" > /dev/null
  echo "✅ Config file created: $OUTPUT_FILE"
  exit 0
fi

if [[ "$MODE" == "apply" ]]; then
  echo "Applying VPP configuration using socket: $VPP_SOCK"
  for c in "${cmds[@]}"; do
    echo "→ vppctl -s $VPP_SOCK $c"
    vppctl -s "$VPP_SOCK" $c || echo "⚠️ Warning: failed or already exists ($c)"
  done
  echo "✅ Configuration applied successfully."
  exit 0
fi

usage
