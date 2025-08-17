#!/bin/bash

# Continuous monitoring script - runs every 30 minutes for 24 hours
LOG_FILE="/home/massey/continuous_monitoring.log"
COUNTER=0
MAX_ITERATIONS=48  # 24 hours * 2 (every 30 minutes)

echo "[$(date)] Starting 24-hour continuous monitoring..." >> "$LOG_FILE"

while [ $COUNTER -lt $MAX_ITERATIONS ]; do
    echo "[$(date)] Monitoring iteration $((COUNTER + 1))/$MAX_ITERATIONS" >> "$LOG_FILE"
    
    # Check critical containers
    for container in homeassistant grafana influxdb pihole; do
        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo "[$(date)] ALERT: $container is not running!" >> "$LOG_FILE"
            # Optionally send alert email here
        fi
    done
    
    # Check for any container restarts
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -v "Up.*hours" | grep -v "NAMES" >> "$LOG_FILE" 2>/dev/null || true
    
    COUNTER=$((COUNTER + 1))
    
    if [ $COUNTER -lt $MAX_ITERATIONS ]; then
        sleep 1800  # Sleep for 30 minutes
    fi
done

echo "[$(date)] 24-hour monitoring complete. Generating final report..." >> "$LOG_FILE"

# Generate final report
/home/massey/timezone_monitoring_script.sh
/home/massey/email_timezone_report.sh

echo "[$(date)] Final report sent." >> "$LOG_FILE"
