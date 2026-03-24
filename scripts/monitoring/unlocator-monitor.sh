#!/bin/bash
# Unlocator VPN/SmartDNS Reliability Monitor
# Runs every 5 minutes via systemd timer
# Logs DNS response times, VPN latency, and reconnect counts to CSV

LOGDIR="/home/${SUDO_USER:-$(whoami)}/unlocator-monitor"
CSV="$LOGDIR/unlocator.csv"
MAXSIZE=10485760  # 10MB rotation threshold

mkdir -p "$LOGDIR"

# CSV header
[ ! -f "$CSV" ] && echo "timestamp,dns1_ms,dns2_ms,tun0_ping_ms,tun1_ping_ms,tun0_reconnects,tun1_reconnects" > "$CSV"

# Rotate if too large
if [ -f "$CSV" ]; then
    FSIZE=$(stat -c%s "$CSV" 2>/dev/null || stat -f%z "$CSV" 2>/dev/null)
    if [ "${FSIZE:-0}" -gt "$MAXSIZE" ]; then
        mv "$CSV" "$CSV.old"
        echo "timestamp,dns1_ms,dns2_ms,tun0_ping_ms,tun1_ping_ms,tun0_reconnects,tun1_reconnects" > "$CSV"
    fi
fi

TS=$(date '+%Y-%m-%dT%H:%M:%S%z')

# --- SmartDNS response times ---
dns_query() {
    local server="$1"
    local output
    output=$(dig @"$server" netflix.com +tries=1 +time=5 +stats 2>/dev/null)
    local ms
    ms=$(echo "$output" | grep "Query time:" | sed 's/.*Query time: \([0-9]*\) msec.*/\1/')
    if [ -n "$ms" ] && [ "$ms" -ge 0 ] 2>/dev/null; then
        echo "$ms"
    else
        echo "-1"
    fi
}

DNS1=$(dns_query "185.37.37.37")
DNS2=$(dns_query "185.37.39.39")

# --- VPN tunnel latency ---
vpn_ping() {
    local iface="$1"
    if ! ip link show "$iface" &>/dev/null; then
        echo "-1"
        return
    fi
    local avg
    avg=$(ping -c 3 -W 2 -I "$iface" 1.1.1.1 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
    if [ -n "$avg" ]; then
        printf "%.1f" "$avg" 2>/dev/null || echo "-1"
    else
        echo "-1"
    fi
}

TUN0_PING=$(vpn_ping "tun0")
TUN1_PING=$(vpn_ping "tun1")

# --- VPN reconnect counts (last 5 minutes) ---
TUN0_RECONN=$(journalctl -u unlocator-vpn --since "5 min ago" --no-pager 2>/dev/null | grep -c "Initialization Sequence Completed" || true)
TUN1_RECONN=$(journalctl -u uk-vpn-prime --since "5 min ago" --no-pager 2>/dev/null | grep -c "Initialization Sequence Completed" || true)
: "${TUN0_RECONN:=0}"
: "${TUN1_RECONN:=0}"

# --- Write CSV row ---
echo "${TS},${DNS1},${DNS2},${TUN0_PING},${TUN1_PING},${TUN0_RECONN},${TUN1_RECONN}" >> "$CSV"
