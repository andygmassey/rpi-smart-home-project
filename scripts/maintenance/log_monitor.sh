#!/bin/bash
# Enhanced Log Monitoring Script

LOG_SIZE_THRESHOLD=80  # MB
LOG_DIR="/var/log"
ALERT_LOG="/var/log/log_monitor.log"

check_large_logs() {
    echo "$(date): Checking for large log files..." >> "$ALERT_LOG"
    
    find "$LOG_DIR" -name "*.log" -size +${LOG_SIZE_THRESHOLD}M -exec ls -lh {} \; | while read -r logfile; do
        echo "$(date): WARNING - Large log detected: $logfile" >> "$ALERT_LOG"
        
        # Auto-rotate if it's a known problematic log
        if [[ "$logfile" == *"kern.log"* ]] || [[ "$logfile" == *"syslog"* ]] || [[ "$logfile" == *"messages"* ]]; then
            echo "$(date): Auto-rotating large system log..." >> "$ALERT_LOG"
            sudo logrotate -f /etc/logrotate.conf
            echo "$(date): Log rotation completed" >> "$ALERT_LOG"
        fi
    done
}

check_large_logs
