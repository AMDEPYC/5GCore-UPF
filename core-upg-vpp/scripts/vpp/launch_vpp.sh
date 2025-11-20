#!/bin/bash
# ============================================================
# launch_vpp.sh
# Launch VPP using /etc/startup.conf
# ============================================================

set -e
POD_ID=${1:-}
VPP_STARTUP_CONF="/etc/startup${POD_ID}.conf"
VPP_SOCK="/run/vpp/cli${POD_ID}.sock"

# --- Check if config exists ---
if [[ ! -f "$VPP_STARTUP_CONF" ]]; then
    echo "❌ Startup config $VPP_STARTUP_CONF not found!"
    exit 1
fi

# --- Stop any running VPP using the socket ---
if [[ -S "$VPP_SOCK" ]]; then
    echo "Stopping existing VPP instance..."
    vppctl -s "$VPP_SOCK" sh int || true
    sleep 2
    if [[ -S "$VPP_SOCK" ]]; then
        echo "⚠️ Socket still exists, killing VPP process..."
        pkill -f "vpp.*$VPP_SOCK" || true
    fi
fi

# --- Start VPP ---
echo "Starting VPP using $VPP_STARTUP_CONF..."
sudo vpp -c "$VPP_STARTUP_CONF" &

# --- Wait a few seconds and check socket ---
sleep 15
if [[ -S "$VPP_SOCK" ]]; then
    echo "✅ VPP started successfully. CLI socket: $VPP_SOCK"
else
    echo "❌ Failed to start VPP. Check logs in /tmp/vpp.log"
    exit 1
fi
