#!/bin/bash
set -e

echo "Example usage:"
echo " sudo $0 <pod_id> <n3_pci_addr> <n6_pci_addr> <n3_workers> <n6_workers> <main_core> <num_sess> <pmd_mgmt_on> <mode>"
echo " Modes: generate | launch | both"
echo

#=== Arguments with defaults ===
POD_ID=${1:-0}
PCI_N3=${2:-0000:41:00.0}
PCI_N6=${3:-0000:41:00.1}
WORKERS_N3=${4:-8-15}
WORKERS_N6=${5:-16-23}
MAIN_CORE=${6:-1}
NUM_SESSIONS=${7:-64}
PMD_MGMT=${8:-off}
MODE=${9:-generate}   # default: run both

echo "INFO: Mode=$MODE, Pod=$POD_ID, N3=$PCI_N3, N6=$PCI_N6, N3-workers=$WORKERS_N3, N6-workers=$WORKERS_N6, main-core=$MAIN_CORE, sessions=$NUM_SESSIONS, PMD=$PMD_MGMT"

#=== Generate session config ===
generate_config() {
    echo "Generating PFCP session config for $NUM_SESSIONS sessions..."
    /5gupf/scripts/pfcp_sim/session_gen.py "$NUM_SESSIONS"
    sleep 2

    echo "Generating UPF VPP config..."
    /5gupf/scripts/vpp/vpp_upf_config.sh generate "$POD_ID"
    sleep 2

    /5gupf/scripts/vpp/generate_vpp_conf.sh "$POD_ID" "$PCI_N3" "$PCI_N6" "$WORKERS_N3" "$WORKERS_N6" "$MAIN_CORE" "$PMD_MGMT"
    sleep 2
}

#=== Launch VPP-UPF and PFCP test ===
launch_test() {
    echo "Launching VPP-UPF..."
    /5gupf/scripts/vpp/launch_vpp.sh "$POD_ID"
    sleep 10

    echo "Starting PFCP simulation..."
    /5gupf/scripts/pfcp_sim/smf_pfcp.sh

    echo "✅ VPP-UPF launched successfully!"
    echo "   Start traffic on N3/N6...!!"
}

#=== Main execution ===
case "$MODE" in
    generate)
        generate_config
        ;;
    launch)
        launch_test
        ;;
    both)
        generate_config
        launch_test
        ;;
    *)
        echo "Error: Unknown mode '$MODE'. Use generate|launch|both"
        exit 1
        ;;
esac
