#!/bin/bash
set -euo pipefail

#=== Configurable variables ===#
NUM_SESSIONS=${1:-64}
IFACE="n4"
LOCAL_IP="192.168.70.1"
REMOTE_IP="192.168.70.201"
PFCP_SESSIONS="/5gupf/scripts/pfcp_sim/pfcp_sessions_with_urr.yaml"
PFCP_PORT=10000
PFCP_REMOTE_PORT=8805
SLEEP_INTERVAL=15   # seconds between interface/session checks
LOG_FILE="/var/log/pfcpclient_monitor.log"
CONF_FILE="/etc/startup*.conf"
VPP_BIN="/usr/bin/vpp"
PFCPCLIENT_BIN="/5gupf/scripts/pfcp_sim/pfcpclient"
SESSION_GEN="/5gupf/scripts/pfcp_sim/session_gen.py"

#=== Helper functions ===#
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

cleanup_pfcpclient() {
    pkill pfcpclient 2>/dev/null || true
    # Wait for ports to be released
    for i in {1..10}; do
        if ! ss -u -lpn | grep -qE ":$PFCP_PORT|:$PFCP_REMOTE_PORT"; then
            break
        fi
        log "Waiting for UDP ports $PFCP_PORT/$PFCP_REMOTE_PORT to be free..."
        sleep 2
    done
    sudo fuser -k -n udp $PFCP_PORT 2>/dev/null || true
    sudo fuser -k -n udp $PFCP_REMOTE_PORT 2>/dev/null || true
}

# Graceful shutdown on Ctrl+C or SIGTERM
trap 'log "Signal received. Cleaning up..."; cleanup_pfcpclient; exit 0' SIGINT SIGTERM

#=== Pre-checks ===#
if ! command -v vppctl &>/dev/null; then
    echo "Error: vppctl not found in PATH" >&2
    exit 1
fi
if [[ ! -f $SESSION_GEN ]]; then
    echo "Error: session_gen.py not found at $SESSION_GEN" >&2
    exit 1
fi

#=== Prepare PFCP session definitions ===#
log "Generating PFCP session file: $PFCP_SESSIONS"
$SESSION_GEN "$NUM_SESSIONS" "$PFCP_SESSIONS"

#=== Bring interface up ===#
ifconfig "$IFACE" "$LOCAL_IP/24" up || log "Warning: could not bring up $IFACE manually"

#=== Get VPP CLI socket ===#
CLI_SOCK=$(grep -oP 'cli-listen\s+\K\S+' $CONF_FILE | head -1 || true)
if [[ -z "$CLI_SOCK" ]]; then
    echo "Error: cli-listen path not found in $CONF_FILE" >&2
    exit 1
fi

log "Using VPP CLI socket: $CLI_SOCK"
sleep "$SLEEP_INTERVAL"

#=== Main Loop ===#
while true; do
    # Wait for interface up
    until ip link show "$IFACE" &>/dev/null && ip addr show "$IFACE" | grep -q "UP"; do
        log "Interface $IFACE is down. Waiting $SLEEP_INTERVAL s..."
        pkill vpp || true
        sleep 5
        $VPP_BIN -c /etc/startup*.conf
        cleanup_pfcpclient
        sleep "$SLEEP_INTERVAL"
    done

    # Ensure local IP is actually bound
    if ! ip addr show "$IFACE" | grep -q "$LOCAL_IP"; then
        log "Assigning IP $LOCAL_IP to $IFACE"
        ip addr add "$LOCAL_IP/24" dev "$IFACE" 2>/dev/null || true
    fi

    # Ensure ports are free before restart
    cleanup_pfcpclient

    # Reset n3/n6 interface before PFCP start
    vppctl -s "$CLI_SOCK" set interface state n3 down
    vppctl -s "$CLI_SOCK" set interface state n6 down
    sleep 2

    log "Interface $IFACE is up. Starting pfcpclient..."
    $PFCPCLIENT_BIN -l "$LOCAL_IP:$PFCP_PORT" -r "$REMOTE_IP:$PFCP_REMOTE_PORT" -s "$PFCP_SESSIONS" &
    PFCP_PID=$!

    sleep "$SLEEP_INTERVAL"
    vppctl -s "$CLI_SOCK" set interface state n3 up
    vppctl -s "$CLI_SOCK" set interface state n6 up

    #=== Monitor pfcpclient ===#
    while kill -0 "$PFCP_PID" 2>/dev/null; do
        # Interface check
        if ! ip addr show "$IFACE" | grep -q "UP"; then
            log "Interface $IFACE went down. Killing pfcpclient..."
            cleanup_pfcpclient
            kill "$PFCP_PID" 2>/dev/null || true
            wait "$PFCP_PID" 2>/dev/null || true
            break
        fi

        # UPF session health check
        SESSION_OUTPUT=$(vppctl -s "$CLI_SOCK" sh upf session || true)
        if [[ -z "$SESSION_OUTPUT" || "$SESSION_OUTPUT" == *"No sessions"* ]]; then
            log "WARNING: UPF sessions missing. Restarting pfcpclient..."
            cleanup_pfcpclient
            kill "$PFCP_PID" 2>/dev/null || true
            wait "$PFCP_PID" 2>/dev/null || true
            break
        fi

        sleep "$SLEEP_INTERVAL"
    done

    log "pfcpclient stopped. Rechecking $IFACE..."
done
