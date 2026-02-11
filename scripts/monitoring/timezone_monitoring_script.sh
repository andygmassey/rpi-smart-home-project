#!/bin/bash

# Timezone Change Monitoring Script
# Created: $(date)
# Purpose: Monitor applications after timezone change from Europe/London to Asia/Hong_Kong

REPORT_FILE="$HOME/timezone_change_report_$(date +%Y%m%d_%H%M).txt"
LOG_DIR="$HOME/timezone_logs"

# Create log directory
mkdir -p "$LOG_DIR"

# Function to log with timestamp
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $1" | tee -a "$REPORT_FILE"
}

# Function to check container health
check_container_health() {
    local container_name="$1"
    local status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")
    local running=$(docker inspect --format='{{.State.Running}}' "$container_name" 2>/dev/null || echo "false")
    
    if [ "$running" = "true" ]; then
        if [ "$status" = "healthy" ] || [ "$status" = "no-healthcheck" ]; then
            echo "✓ $container_name: Running ($status)"
        else
            echo "⚠ $container_name: Running but $status"
        fi
    else
        echo "✗ $container_name: Not running"
    fi
}

# Function to capture container logs
capture_logs() {
    local container_name="$1"
    local lines="${2:-20}"
    
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_with_timestamp "Capturing logs for $container_name (last $lines lines):"
        docker logs --tail "$lines" --timestamps "$container_name" 2>&1 | tee -a "$REPORT_FILE"
        echo "" | tee -a "$REPORT_FILE"
    fi
}

# Function to test application endpoints
test_endpoints() {
    log_with_timestamp "Testing application endpoints:"
    
    # Test Home Assistant (assuming port 8123)
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8123 | grep -q "200\|302"; then
        echo "✓ Home Assistant: Accessible" | tee -a "$REPORT_FILE"
    else
        echo "⚠ Home Assistant: May have issues" | tee -a "$REPORT_FILE"
    fi
    
    # Test Grafana
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3002 | grep -q "200\|302"; then
        echo "✓ Grafana: Accessible" | tee -a "$REPORT_FILE"
    else
        echo "⚠ Grafana: May have issues" | tee -a "$REPORT_FILE"
    fi
    
    # Test Pi-hole
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302"; then
        echo "✓ Pi-hole: Accessible" | tee -a "$REPORT_FILE"
    else
        echo "⚠ Pi-hole: May have issues" | tee -a "$REPORT_FILE"
    fi
    
    # Test InfluxDB
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8086/ping | grep -q "204"; then
        echo "✓ InfluxDB: Accessible" | tee -a "$REPORT_FILE"
    else
        echo "⚠ InfluxDB: May have issues" | tee -a "$REPORT_FILE"
    fi
    
    echo "" | tee -a "$REPORT_FILE"
}

# Function to check timestamp consistency
check_timestamps() {
    log_with_timestamp "Checking timestamp consistency across systems:"
    
    echo "System time: $(date)" | tee -a "$REPORT_FILE"
    echo "System timezone: $(timedatectl | grep 'Time zone')" | tee -a "$REPORT_FILE"
    
    # Check if containers are using correct timezone
    if docker exec homeassistant date 2>/dev/null; then
        echo "Home Assistant container time: $(docker exec homeassistant date 2>/dev/null)" | tee -a "$REPORT_FILE"
    fi
    
    if docker exec grafana date 2>/dev/null; then
        echo "Grafana container time: $(docker exec grafana date 2>/dev/null)" | tee -a "$REPORT_FILE"
    fi
    
    echo "" | tee -a "$REPORT_FILE"
}

# Main monitoring function
main_monitoring() {
    log_with_timestamp "=== TIMEZONE CHANGE IMPACT MONITORING REPORT ===" 
    log_with_timestamp "Timezone changed from Europe/London (BST) to Asia/Hong_Kong (HKT)"
    log_with_timestamp "Change occurred at: $(date)"
    echo "" | tee -a "$REPORT_FILE"
    
    # Check system timezone
    log_with_timestamp "Current system configuration:"
    timedatectl status | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    
    # Check container statuses
    log_with_timestamp "Docker container health status:"
    check_container_health "homeassistant"
    check_container_health "grafana" 
    check_container_health "influxdb"
    check_container_health "pihole"
    check_container_health "mosquitto"
    check_container_health "uptime-kuma"
    check_container_health "homepage"
    echo "" | tee -a "$REPORT_FILE"
    
    # Test endpoints
    test_endpoints
    
    # Check timestamps
    check_timestamps
    
    # Capture recent logs for critical services
    log_with_timestamp "Recent logs from critical services:"
    capture_logs "homeassistant" 15
    capture_logs "grafana" 10
    capture_logs "influxdb" 10
    
    log_with_timestamp "=== MONITORING REPORT COMPLETE ==="
}

# Run initial monitoring
main_monitoring

# Set up continuous monitoring (every 30 minutes for 24 hours)
log_with_timestamp "Setting up continuous monitoring for 24 hours (every 30 minutes)..."

