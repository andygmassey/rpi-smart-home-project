#!/bin/bash

# Raspberry Pi Vitals Monitor - sends data to InfluxDB
# Run this every minute via cron

INFLUX_HOST="localhost"
INFLUX_PORT="8086"
INFLUX_DB="smarthome"

# Get system metrics
CPU_TEMP=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d% -f1)
MEMORY_TOTAL=$(free -m | awk 'NR==2{print $2}')
MEMORY_USED=$(free -m | awk 'NR==2{print $3}')
MEMORY_PERCENT=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | cut -d% -f1)
DISK_AVAIL=$(df -BG / | awk 'NR==2{print $4}' | cut -dG -f1)
SWAP_USED=$(free -m | awk 'NR==3{print $3}')
SWAP_TOTAL=$(free -m | awk 'NR==3{print $2}')
UPTIME_DAYS=$(uptime | awk -F'( |,|:)+' '{print $6}')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')

# Get network stats
RX_BYTES=$(cat /sys/class/net/eth0/statistics/rx_bytes 2>/dev/null || echo 0)
TX_BYTES=$(cat /sys/class/net/eth0/statistics/tx_bytes 2>/dev/null || echo 0)

# Current timestamp
TIMESTAMP=$(date +%s)000000000

# Create InfluxDB line protocol data
DATA="system_vitals,host=rpi4,type=temperature cpu_temp=${CPU_TEMP} ${TIMESTAMP}
system_vitals,host=rpi4,type=cpu cpu_usage=${CPU_USAGE} ${TIMESTAMP}
system_vitals,host=rpi4,type=memory memory_used=${MEMORY_USED},memory_total=${MEMORY_TOTAL},memory_percent=${MEMORY_PERCENT} ${TIMESTAMP}
system_vitals,host=rpi4,type=disk disk_usage_percent=${DISK_USAGE},disk_available_gb=${DISK_AVAIL} ${TIMESTAMP}
system_vitals,host=rpi4,type=swap swap_used=${SWAP_USED},swap_total=${SWAP_TOTAL} ${TIMESTAMP}
system_vitals,host=rpi4,type=system load_avg=${LOAD_AVG},uptime_days=${UPTIME_DAYS} ${TIMESTAMP}
system_vitals,host=rpi4,type=network rx_bytes=${RX_BYTES},tx_bytes=${TX_BYTES} ${TIMESTAMP}"

# Send to InfluxDB
curl -i -XPOST "http://${INFLUX_HOST}:${INFLUX_PORT}/write?db=${INFLUX_DB}" --data-binary "$DATA" >/dev/null 2>&1

echo "[$(date)] RPi vitals sent to InfluxDB"
