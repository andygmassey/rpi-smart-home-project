#!/bin/bash
# Memory Cleanup Script - Fixed version
LOG_FILE="/var/log/memory_cleanup.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
}

# Check for lxpanel memory issues
LXPANEL_PID=$(pgrep lxpanel)
if [[ -n "$LXPANEL_PID" ]]; then
    LXPANEL_MEM=$(ps -p "$LXPANEL_PID" -o rss= 2>/dev/null)
    if [[ -n "$LXPANEL_MEM" ]] && [[ "$LXPANEL_MEM" -gt 500000 ]]; then
        log_message "WARNING: lxpanel using ${LXPANEL_MEM}KB memory - restarting desktop"
        sudo systemctl restart lightdm
        log_message "Desktop environment restarted"
    fi
fi

# Check swap usage
SWAP_INFO=$(free | awk '/^Swap:/')
SWAP_TOTAL=$(echo "$SWAP_INFO" | awk '{print $2}')
SWAP_USED=$(echo "$SWAP_INFO" | awk '{print $3}')
if [[ "$SWAP_TOTAL" -gt 0 ]]; then
    SWAP_PERCENT=$(echo "$SWAP_USED $SWAP_TOTAL" | awk '{printf "%.0f", $1*100/$2}')
    if [[ "$SWAP_PERCENT" -gt 40 ]]; then
        log_message "WARNING: Swap usage at ${SWAP_PERCENT}% - optimizing"
        sudo swapoff -a && sudo swapon -a
        log_message "Swap optimized"
    fi
    log_message "Memory cleanup completed - Swap: ${SWAP_PERCENT}%"
else
    log_message "Memory cleanup completed - Swap: 0%"
fi

# Clean zombie processes
ZOMBIE_COUNT=$(ps aux | awk '$8 ~ /^Z/ {count++} END {print count+0}')
if [[ "$ZOMBIE_COUNT" -gt 0 ]]; then
    log_message "Cleaning $ZOMBIE_COUNT zombie processes"
    sudo pkill -9 -f "chromium-browse"
fi
