#!/bin/bash
# Called by OpenVPN route-up for uk-vpn (tun1) — runs on every connect/reconnect
# OpenVPN sets: $ifconfig_remote (peer/gateway IP), $dev (tun1)
APPLE_TV=192.168.1.23

GW="${ifconfig_remote}"
DEV="${dev:-tun1}"

if [ -z "$GW" ]; then
    # Fallback: read peer from interface
    GW=$(ip -4 addr show "${DEV}" 2>/dev/null | grep -oP 'peer \K[0-9.]+')
fi

if [ -z "$GW" ]; then
    echo "setup-uk-vpn-routes: cannot determine gateway, aborting" >&2
    exit 1
fi

echo "setup-uk-vpn-routes: rebuilding ukvpn table (dev=$DEV, gw=$GW)"

# Ensure ukvpn table exists
grep -q "^100 ukvpn" /etc/iproute2/rt_tables 2>/dev/null || echo "100 ukvpn" >> /etc/iproute2/rt_tables

# Rebuild ukvpn routing table
ip route flush table ukvpn 2>/dev/null
ip route add default via "$GW" dev "$DEV" table ukvpn
ip route add 192.168.1.0/24 dev eth0 table ukvpn

# Ensure Apple TV policy rule
ip rule del from "$APPLE_TV" lookup ukvpn 2>/dev/null
ip rule add from "$APPLE_TV" lookup ukvpn priority 32765

# Ensure iptables MASQUERADE
iptables -t nat -C POSTROUTING -s "$APPLE_TV" -o "$DEV" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$APPLE_TV" -o "$DEV" -j MASQUERADE

echo "setup-uk-vpn-routes: Apple TV ($APPLE_TV) → UK VPN ($DEV via $GW)"
