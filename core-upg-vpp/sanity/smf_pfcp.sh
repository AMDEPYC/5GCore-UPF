#!/bin/bash

# Configurable variables
IFACE="n4"
LOCAL_IP="192.168.70.1"
REMOTE_IP="192.168.70.201"
PFCP_SESSIONS="pfcp_64sessions_with_urr.yaml"
PFCP_PORT=10000
PFCP_REMOTE_PORT=8805
SLEEP_INTERVAL=300   # seconds between interface/session checks
LOG_FILE="pfcpclient_monitor.log"

# Assign IP to n4 (idempotent)
ifconfig $IFACE $LOCAL_IP/24 up

# Kill any leftover pfcpclient processes
pkill pfcpclient 2>/dev/null || true

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $*"
}

while true; do
    # Wait until interface is up
    until ip link show $IFACE &>/dev/null && ip addr show $IFACE | grep -q "UP"; do
        log "Interface $IFACE is down. Waiting $SLEEP_INTERVAL s..."
        sleep $SLEEP_INTERVAL
    done

    log "Interface $IFACE is up. Starting pfcpclient..."
    ./pfcpclient -l $LOCAL_IP:$PFCP_PORT -r $REMOTE_IP:$PFCP_REMOTE_PORT -s $PFCP_SESSIONS &
    PFCP_PID=$!
    sleep $SLEEP_INTERVAL

    # Monitor pfcpclient and interface status
    while kill -0 $PFCP_PID 2>/dev/null; do
        # Check interface
        if ! ip addr show $IFACE | grep -q "UP"; then
            log "Interface $IFACE went down. Killing pfcpclient..."
            kill $PFCP_PID
            wait $PFCP_PID 2>/dev/null
            break
        fi

        # Check UPF sessions
        SESSION_OUTPUT=$(vppctl sh upf session)
        if [[ -z "$SESSION_OUTPUT" || "$SESSION_OUTPUT" == *"No sessions"* ]]; then
            log "WARNING: UPF sessions missing. Restarting pfcpclient..."
            kill $PFCP_PID
            wait $PFCP_PID 2>/dev/null
            PFCP_PID=""
            break
        fi

        sleep $SLEEP_INTERVAL
    done

    log "pfcpclient stopped. Checking $IFACE again..."
done
