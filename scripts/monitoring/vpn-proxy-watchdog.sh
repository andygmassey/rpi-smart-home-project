#!/bin/bash
# VPN Proxy Watchdog - Ensures VPN and proxy stay healthy
# Runs every 2 minutes via systemd timer

set -euo pipefail

LOG_FILE="$HOME/vpn-proxy-watchdog.log"
STATE_FILE="$HOME/.vpn-proxy-watchdog-state"
MAX_RESTARTS_PER_HOUR=3
COOLDOWN_SECONDS=300  # 5 minutes

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] ${@:2}" >> "$LOG_FILE"
}

# State management
get_state() {
    grep "^$1=" "$STATE_FILE" 2>/dev/null | cut -d= -f2 || echo "${2:-0}"
}

set_state() {
    if [[ -f "$STATE_FILE" ]]; then
        grep -v "^$1=" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
        mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi
    echo "$1=$2" >> "$STATE_FILE"
}

can_restart() {
    local now=$(date +%s)
    local last_restart=$(get_state "last_restart" "0")
    local restart_count=$(get_state "restart_count_hour" "0")
    local current_hour=$(date +%H)
    local saved_hour=$(get_state "saved_hour" "-1")
    
    # Reset hourly counter
    if [[ "$current_hour" != "$saved_hour" ]]; then
        restart_count=0
        set_state "restart_count_hour" "0"
        set_state "saved_hour" "$current_hour"
    fi
    
    # Check cooldown
    local time_since=$((now - last_restart))
    if [[ $time_since -lt $COOLDOWN_SECONDS ]]; then
        log "WARN" "Cooldown active: ${time_since}s since last restart (need ${COOLDOWN_SECONDS}s)"
        return 1
    fi
    
    # Check hourly limit
    if [[ $restart_count -ge $MAX_RESTARTS_PER_HOUR ]]; then
        log "ERROR" "Hourly restart limit reached ($MAX_RESTARTS_PER_HOUR)"
        return 1
    fi
    
    return 0
}

record_restart() {
    set_state "last_restart" "$(date +%s)"
    local count=$(get_state "restart_count_hour" "0")
    set_state "restart_count_hour" "$((count + 1))"
    log "INFO" "Restart recorded. Count this hour: $((count + 1))/$MAX_RESTARTS_PER_HOUR"
}

# Health checks
check_vpn_connected() {
    ip addr show tun0 &>/dev/null && ip addr show tun0 | grep -q "inet "
}

check_proxy_responding() {
    timeout 5 nc -z 127.0.0.1 1080 2>/dev/null
}

check_proxy_works() {
    local test_ip
    test_ip=$(timeout 10 curl -s --socks5-hostname 127.0.0.1:1080 https://api.ipify.org 2>/dev/null)
    [[ -n "$test_ip" ]] && [[ "$test_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Main watchdog
log "INFO" "=== VPN Proxy Watchdog Check ==="

issues=()

# Check VPN
if ! check_vpn_connected; then
    log "ERROR" "VPN not connected"
    issues+=("vpn_down")
else
    log "OK" "VPN connected"
fi

# Check proxy listening
if ! check_proxy_responding; then
    log "ERROR" "Proxy not responding on port 1080"
    issues+=("proxy_down")
else
    log "OK" "Proxy listening"
fi

# Check proxy actually works (end-to-end)
if ! check_proxy_works; then
    log "ERROR" "Proxy connectivity test failed"
    issues+=("proxy_broken")
else
    log "OK" "Proxy connectivity OK"
fi

# Take action if needed
if [[ ${#issues[@]} -gt 0 ]]; then
    log "WARN" "Issues detected: ${issues[*]}"
    
    if can_restart; then
        log "WARN" "Restarting VPN proxy..."
        systemctl restart unlocator-vpn vpn-proxy
        record_restart
        
        # Wait and verify
        sleep 10
        if check_proxy_works; then
            log "OK" "Restart successful"
        else
            log "ERROR" "Restart did not fix the issue"
        fi
    fi
else
    log "OK" "All checks passed"
fi

log "INFO" "=== Check Complete ==="

# Rotate log if > 5MB
if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt 5242880 ]]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
    log "INFO" "Log rotated"
fi
