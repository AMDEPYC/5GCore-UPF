#!/bin/bash

# === Configuration ===
IFACE=${IFACE:-"eth0"}
LOCAL_IP=${LOCAL_IP:-"192.168.1.1"}
PFCP_PORT=${PFCP_PORT:-8805}
REMOTE_IP=${REMOTE_IP:-"192.168.1.100"}
PFCP_REMOTE_PORT=${PFCP_REMOTE_PORT:-8805}
PFCP_SESSIONS=${PFCP_SESSIONS:-16}
SLEEP_INTERVAL=${SLEEP_INTERVAL:-10}

VPP_BIN=${VPP_BIN:-"/usr/bin/vpp"}
PFCPCLIENT_BIN=${PFCPCLIENT_BIN:-"/usr/bin/pfcpclient"}
CLI_SOCK=${CLI_SOCK:-"/run/vpp/cli.sock"}

LOG_FILE=${LOG_FILE:-"/tmp/pfcp_monitor.log"}

log() {
    echo "$(date '+%F %T') - $*" | tee -a "$LOG_FILE"
}

cleanup_pfcpclient() {
    if [[ -n "$PFCP_PID" ]] && kill -0 "$PFCP_PID" 2>/dev/null; then
        log "Stopping pfcpclient (PID $PFCP_PID)..."
        kill "$PFCP_PID" 2>/dev/null || true
        wait "$PFCP_PID" 2>/dev/null || true
    fi
}

restart_vpp() {
    local vpp_pid
    vpp_pid=$(pidof vpp)
    if [[ -n "$vpp_pid" ]]; then
        log "Stopping VPP (PID $vpp_pid)..."
        kill "$vpp_pid" || true
        wait "$vpp_pid" 2>/dev/null || true
    fi
    log "Starting VPP..."
    $VPP_BIN -c /etc/startup*.conf >> "$LOG_FILE" 2>&1 &
    sleep 3
}

ensure_ip() {
    if ! ip addr show "$IFACE" | grep -q "$LOCAL_IP"; then
        log "Assigning IP $LOCAL_IP to $IFACE..."
        ip addr add "$LOCAL_IP/24" dev "$IFACE" 2>/dev/null || true
    fi
}

reset_vpp_interfaces() {
    vppctl -s "$CLI_SOCK" set interface state n3 down
    vppctl -s "$CLI_SOCK" set interface state n6 down
    sleep 2
}

bring_up_vpp_interfaces() {
    vppctl -s "$CLI_SOCK" set interface state n3 up
    vppctl -s "$CLI_SOCK" set interface state n6 up
}

start_pfcpclient() {
    log "Starting pfcpclient..."
    $PFCPCLIENT_BIN -l "$LOCAL_IP:$PFCP_PORT" \
                    -r "$REMOTE_IP:$PFCP_REMOTE_PORT" \
                    -s "$PFCP_SESSIONS" >> "$LOG_FILE" 2>&1 &
    PFCP_PID=$!
    log "pfcpclient started with PID $PFCP_PID"
}

monitor_pfcpclient() {
    while kill -0 "$PFCP_PID" 2>/dev/null; do
        # Interface check
        if ! ip addr show "$IFACE" | grep -q "UP"; then
            log "Interface $IFACE went down."
            cleanup_pfcpclient
            #restart_vpp
            break
        fi

        # UPF session health check
        SESSION_OUTPUT=$(vppctl -s "$CLI_SOCK" sh upf session || true)
        if [[ -z "$SESSION_OUTPUT" || "$SESSION_OUTPUT" == *"No sessions"* ]]; then
            log "WARNING: UPF sessions missing."
            cleanup_pfcpclient
            break
        fi

        sleep "$SLEEP_INTERVAL"
    done
}

# === Main loop ===
while true; do
    # Wait for interface to be up
    until ip link show "$IFACE" &>/dev/null && ip addr show "$IFACE" | grep -q "UP"; do
        log "Interface $IFACE is down. Waiting $SLEEP_INTERVAL s..."
        sleep "$SLEEP_INTERVAL"
    done

    ensure_ip
    cleanup_pfcpclient
    reset_vpp_interfaces
    start_pfcpclient
    sleep "$SLEEP_INTERVAL"
    bring_up_vpp_interfaces
    monitor_pfcpclient

    log "pfcpclient stopped. Rechecking $IFACE..."
done
