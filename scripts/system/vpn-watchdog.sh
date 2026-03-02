#!/bin/bash
# VPN Watchdog — monitors tun0 (main VPN) and tun1 (UK VPN)
# Restarts VPNs in correct order if tunnels go down.
# Runs every 5 minutes via cron.

LOG=/var/log/vpn-watchdog.log
COOLDOWN_FILE=/tmp/vpn-watchdog-restarted
COOLDOWN_SECS=600  # 10 min — don't restart again within this window

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

# Check cooldown — avoid restart loops
if [ -f "$COOLDOWN_FILE" ]; then
    last=$(cat "$COOLDOWN_FILE" 2>/dev/null)
    now=$(date +%s)
    if [ -n "$last" ] && [ $(( now - last )) -lt $COOLDOWN_SECS ]; then
        log "Cooldown active (last restart $(( now - last ))s ago, cooldown ${COOLDOWN_SECS}s) — skipping"
        exit 0
    fi
fi

# Check tunnel status
TUN0_IP=$(ip -4 addr show tun0 2>/dev/null | grep -oP 'inet \K[0-9.]+')
TUN1_IP=$(ip -4 addr show tun1 2>/dev/null | grep -oP 'inet \K[0-9.]+')

TUN0_OK=false
TUN1_OK=false
[ -n "$TUN0_IP" ] && TUN0_OK=true
[ -n "$TUN1_IP" ] && TUN1_OK=true

# Also verify main VPN routes are on tun0 (not tangled to tun1)
ROUTE_OK=true
if $TUN0_OK; then
    BAD_ROUTES=$(ip route show | grep -E '0\.0\.0\.0/1|128\.0\.0\.0/1' | grep -v 'tun0')
    [ -n "$BAD_ROUTES" ] && ROUTE_OK=false && log "WARNING: default split routes not on tun0: $BAD_ROUTES"
fi

if $TUN0_OK && $TUN1_OK && $ROUTE_OK; then
    # All good — log silently (only log issues)
    exit 0
fi

log "=== VPN issue detected: tun0=$( $TUN0_OK && echo UP || echo DOWN) tun1=$( $TUN1_OK && echo UP || echo DOWN) routes=$( $ROUTE_OK && echo OK || echo TANGLED) ==="

# Mark cooldown timestamp
date +%s > "$COOLDOWN_FILE"

if ! $TUN0_OK || ! $ROUTE_OK; then
    # Main VPN down or routes tangled — full restart sequence
    log "Restarting full VPN stack..."
    systemctl restart unlocator-vpn
    log "Waiting 15s for main VPN to establish..."
    sleep 15

    # Verify tun0 came back
    TUN0_IP=$(ip -4 addr show tun0 2>/dev/null | grep -oP 'inet \K[0-9.]+')
    if [ -z "$TUN0_IP" ]; then
        log "ERROR: tun0 still down after restart — giving up (check unlocator-vpn)"
        exit 1
    fi
    log "tun0 back: $TUN0_IP"

    log "Restarting uk-vpn-prime..."
    systemctl restart uk-vpn-prime
    sleep 15
    log "Restarting vpn-proxy..."
    systemctl restart vpn-proxy

elif ! $TUN1_OK; then
    # Only UK VPN down — restart tun1 and proxy only
    log "Only UK VPN (tun1) down — restarting uk-vpn-prime..."
    systemctl restart uk-vpn-prime
    sleep 15
    log "Restarting vpn-proxy..."
    systemctl restart vpn-proxy
fi

# Final status check
sleep 5
TUN0_IP=$(ip -4 addr show tun0 2>/dev/null | grep -oP 'inet \K[0-9.]+')
TUN1_IP=$(ip -4 addr show tun1 2>/dev/null | grep -oP 'inet \K[0-9.]+')
log "Post-restart: tun0=${TUN0_IP:-DOWN} tun1=${TUN1_IP:-DOWN}"
