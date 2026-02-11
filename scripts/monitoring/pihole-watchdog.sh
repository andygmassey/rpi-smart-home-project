#!/bin/bash
# Pi-hole Smart Watchdog - Coordinated Self-Healing System
#
# Responsibilities:
#   - Monitor Pi-hole health (DNS response, memory, database)
#   - Take corrective action with cooldowns (no restart storms)
#   - Escalate through levels: cleanup → restart → hard restart → alert
#   - Log all actions for debugging
#
# Coordination:
#   - Docker restart policy handles container crashes (Layer 1)
#   - This script handles "running but unhealthy" (Layer 2)
#   - Systemd handles boot startup only (Layer 3)
#
# Run via cron every 2 minutes:
#   */2 * * * * $HOME/pihole-watchdog.sh

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

PIHOLE_CONTAINER="pihole"
PIHOLE_DIR="$HOME/pihole-docker"
LOG_FILE="$HOME/pihole-watchdog.log"
STATE_FILE="$HOME/.pihole-watchdog-state"

# Thresholds
DNS_TIMEOUT=5                    # Seconds to wait for DNS response
MAX_DB_SIZE_MB=500               # Alert if database exceeds this
MEMORY_CRITICAL_PERCENT=90       # Run cleanup if memory usage exceeds this
MAX_RESTARTS_PER_HOUR=3          # Prevent restart storms
COOLDOWN_SECONDS=300             # 5 minutes between restart attempts

# Test domains (use multiple for reliability)
TEST_DOMAINS=("google.com" "cloudflare.com" "amazon.com")

# =============================================================================
# LOGGING
# =============================================================================

log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE"

    # Also output to stdout if running interactively
    if [[ -t 1 ]]; then
        echo "[$level] $*"
    fi
}

log_info()  { log "INFO" "$@"; }
log_warn()  { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_ok()    { log "OK" "$@"; }

# =============================================================================
# STATE MANAGEMENT (for cooldowns)
# =============================================================================

get_state() {
    local key="$1"
    local default="${2:-0}"
    if [[ -f "$STATE_FILE" ]]; then
        grep "^${key}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2 || echo "$default"
    else
        echo "$default"
    fi
}

set_state() {
    local key="$1"
    local value="$2"

    # Create or update state file
    if [[ -f "$STATE_FILE" ]]; then
        grep -v "^${key}=" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
        mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi
    echo "${key}=${value}" >> "$STATE_FILE"
}

# =============================================================================
# HEALTH CHECKS
# =============================================================================

check_container_running() {
    docker ps --format '{{.Names}}' | grep -q "^${PIHOLE_CONTAINER}$"
}

check_dns_responding() {
    local success=0

    for domain in "${TEST_DOMAINS[@]}"; do
        if timeout "$DNS_TIMEOUT" dig @127.0.0.1 "$domain" +short > /dev/null 2>&1; then
            ((success++))
        fi
    done

    # Require at least 2 out of 3 to pass
    [[ $success -ge 2 ]]
}

get_memory_percent() {
    free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}'
}

get_database_size_mb() {
    local db_path="$PIHOLE_DIR/etc-pihole/pihole-FTL.db"
    if [[ -f "$db_path" ]]; then
        du -m "$db_path" | cut -f1
    else
        echo "0"
    fi
}

get_container_restart_count() {
    docker inspect "$PIHOLE_CONTAINER" --format='{{.RestartCount}}' 2>/dev/null || echo "0"
}

# =============================================================================
# COOLDOWN MANAGEMENT
# =============================================================================

can_restart() {
    local now
    now=$(date +%s)

    local last_restart
    last_restart=$(get_state "last_restart" "0")

    local restart_count_hour
    restart_count_hour=$(get_state "restart_count_hour" "0")

    local hour_start
    hour_start=$(get_state "hour_start" "0")

    # Reset hourly counter if we're in a new hour
    local current_hour
    current_hour=$(date +%H)
    local saved_hour
    saved_hour=$(get_state "saved_hour" "-1")

    if [[ "$current_hour" != "$saved_hour" ]]; then
        restart_count_hour=0
        set_state "restart_count_hour" "0"
        set_state "saved_hour" "$current_hour"
    fi

    # Check cooldown period
    local time_since_last=$((now - last_restart))
    if [[ $time_since_last -lt $COOLDOWN_SECONDS ]]; then
        log_warn "Cooldown active: ${time_since_last}s since last restart (need ${COOLDOWN_SECONDS}s)"
        return 1
    fi

    # Check hourly limit
    if [[ $restart_count_hour -ge $MAX_RESTARTS_PER_HOUR ]]; then
        log_error "Hourly restart limit reached ($MAX_RESTARTS_PER_HOUR). Manual intervention required."
        send_alert "Pi-hole restart limit reached - manual intervention required"
        return 1
    fi

    return 0
}

record_restart() {
    set_state "last_restart" "$(date +%s)"

    local count
    count=$(get_state "restart_count_hour" "0")
    set_state "restart_count_hour" "$((count + 1))"

    log_info "Restart recorded. Count this hour: $((count + 1))/$MAX_RESTARTS_PER_HOUR"
}

# =============================================================================
# CORRECTIVE ACTIONS
# =============================================================================

run_memory_cleanup() {
    log_info "Running memory cleanup..."

    # Clear page cache (safe operation)
    sync
    echo 1 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true

    # Clear systemd journal if it's large
    sudo journalctl --vacuum-time=2d > /dev/null 2>&1 || true

    log_info "Memory cleanup complete"
}

restart_pihole_soft() {
    log_warn "Performing soft restart of Pi-hole..."

    cd "$PIHOLE_DIR"
    docker compose restart "$PIHOLE_CONTAINER"

    # Wait for startup
    sleep 10

    record_restart
    log_info "Soft restart complete"
}

restart_pihole_hard() {
    log_warn "Performing hard restart of Pi-hole (down + up)..."

    cd "$PIHOLE_DIR"
    docker compose down
    sleep 5
    docker compose up -d

    # Wait for startup
    sleep 15

    record_restart
    log_info "Hard restart complete"
}

send_alert() {
    local message="$1"

    log_error "ALERT: $message"

    # Write to a persistent alert file that can be checked
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$HOME/pihole-alerts.log"

    # Could add email/pushover/webhook here in the future
    # curl -s -X POST "http://webhook.url" -d "message=$message" || true
}

# =============================================================================
# MAIN WATCHDOG LOGIC
# =============================================================================

run_watchdog() {
    log_info "=== Pi-hole Watchdog Check ==="

    local issues=()
    local needs_restart=false
    local needs_hard_restart=false

    # Check 1: Container running?
    if ! check_container_running; then
        log_error "Container not running - Docker restart policy should handle this"
        # Don't take action - let Docker's restart policy work (Layer 1)
        # If it's been down too long, Docker has likely given up

        local docker_restarts
        docker_restarts=$(get_container_restart_count)
        if [[ $docker_restarts -gt 0 ]]; then
            log_warn "Docker has attempted $docker_restarts restarts"
            if [[ $docker_restarts -ge 3 ]]; then
                log_error "Docker restart policy exhausted. Attempting hard restart."
                needs_hard_restart=true
            fi
        else
            # Container stopped cleanly (not crash loop)
            log_warn "Container stopped (not crashed). Starting..."
            needs_restart=true
        fi
        issues+=("container_not_running")
    else
        log_ok "Container running"

        # Check 2: DNS responding? (only if container is running)
        if ! check_dns_responding; then
            log_error "DNS not responding"
            issues+=("dns_not_responding")
            needs_restart=true
        else
            log_ok "DNS responding"
        fi
    fi

    # Check 3: Memory pressure?
    local mem_percent
    mem_percent=$(get_memory_percent)
    if [[ $mem_percent -ge $MEMORY_CRITICAL_PERCENT ]]; then
        log_warn "Memory critical: ${mem_percent}%"
        issues+=("memory_critical")
        run_memory_cleanup
    else
        log_ok "Memory OK: ${mem_percent}%"
    fi

    # Check 4: Database size?
    local db_size
    db_size=$(get_database_size_mb)
    if [[ $db_size -ge $MAX_DB_SIZE_MB ]]; then
        log_error "Database too large: ${db_size}MB (limit: ${MAX_DB_SIZE_MB}MB)"
        issues+=("database_large")
        send_alert "Pi-hole database is ${db_size}MB - consider cleanup"
    else
        log_ok "Database size OK: ${db_size}MB"
    fi

    # Take action if needed
    if [[ "$needs_hard_restart" == "true" ]]; then
        if can_restart; then
            run_memory_cleanup
            restart_pihole_hard
        fi
    elif [[ "$needs_restart" == "true" ]]; then
        if can_restart; then
            run_memory_cleanup
            restart_pihole_soft

            # Verify restart worked
            sleep 5
            if ! check_dns_responding; then
                log_error "Soft restart didn't fix DNS - trying hard restart"
                if can_restart; then
                    restart_pihole_hard
                fi
            fi
        fi
    fi

    # Summary
    if [[ ${#issues[@]} -eq 0 ]]; then
        log_ok "All checks passed"
    else
        log_warn "Issues detected: ${issues[*]}"
    fi

    log_info "=== Check Complete ==="
}

# =============================================================================
# ENTRY POINT
# =============================================================================

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Rotate log if too large (>10MB)
if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null) -gt 10485760 ]]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
    log_info "Log rotated"
fi

# Run the watchdog
run_watchdog
