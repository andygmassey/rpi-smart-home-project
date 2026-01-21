#!/bin/bash
# Automated safe backup (no prompts)
LOG_FILE="/home/massey/backup-$(date +%Y%m%d-%H%M).log"

{
    echo "=== AUTOMATED SAFE BACKUP STARTED: $(date) ==="
    echo ""
    
    echo "1/4 Stopping non-essential services..."
    docker stop homepage grafana uptime-kuma
    
    echo "2/4 Waiting for memory to clear..."
    sleep 15
    
    echo "3/4 Starting backup (will take 20-40 minutes)..."
    /home/massey/create-goldmaster-backup-compressed.sh
    
    echo ""
    echo "4/4 Restarting services..."
    cd /home/massey/homepage-dashboard && docker-compose up -d
    cd /home/massey/grafana-influx && docker-compose up -d  
    cd /home/massey/uptime-kuma && docker-compose up -d
    
    echo ""
    echo "=== BACKUP COMPLETE: $(date) ==="
    echo "Check /media/massey/RPI-BACKUP/ for backup file"
    
} >> "$LOG_FILE" 2>&1

# Send notification via logger
logger "reTerminal backup completed - see $LOG_FILE"
