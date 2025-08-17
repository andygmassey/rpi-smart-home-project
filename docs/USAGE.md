# Usage Guide

Complete guide for operating and maintaining your Raspberry Pi Smart Home System.

## Daily Operations

### Starting Services
```bash
cd ~/rpi-smart-home-project

# Start all services
docker-compose -f docker/grafana-influx/docker-compose.yml up -d
docker-compose -f docker/pihole/docker-compose.yml up -d
docker-compose -f docker/mqtt-broker/docker-compose.yml up -d
docker-compose -f docker/homepage/docker-compose.yml up -d
docker-compose -f docker/uptime-kuma/docker-compose.yml up -d

# Or use the management script
./scripts/system/manage-services.sh start
```

### Stopping Services
```bash
# Stop individual service
docker-compose -f docker/grafana-influx/docker-compose.yml down

# Stop all Docker containers
docker stop $(docker ps -q)

# Or use management script
./scripts/system/manage-services.sh stop
```

### Checking Service Status
```bash
# View running containers
docker ps

# Check specific service logs
docker logs grafana
docker logs influxdb
docker logs pihole

# Check resource usage
docker stats

# Check system health
./scripts/monitoring/system-health-check.sh
```

## Web Interface Access

### Primary Dashboards
- **Homepage Dashboard**: http://localhost:3000 (main dashboard)
- **Home Assistant**: http://localhost:8123 (automation control)
- **Grafana**: http://localhost:3000 (data visualization)
- **Pi-hole Admin**: http://localhost/admin (DNS management)
- **Uptime Kuma**: http://localhost:3001 (service monitoring)

### Quick Access from reTerminal
```bash
# Launch Home Assistant kiosk mode
./scripts/system/launch-ha-kiosk.sh

# Control kiosk display
./scripts/system/control-kiosk.sh [start|stop|restart]
```

## System Management

### Backup Operations

#### Create Application Backup
```bash
# Full application backup (recommended)
./scripts/backup/create-app-backup.sh

# Quick backup to external drive
./scripts/backup/backup-to-external.sh

# Create golden master backup
./scripts/backup/create-master-backup.sh
```

#### Restore from Backup
```bash
# List available backups
ls ~/backups/

# Restore application backup
./scripts/backup/restore-app-backup.sh /path/to/backup.tar.gz

# Use backup manager for guided restore
./scripts/backup/backup-manager.sh restore
```

### System Monitoring

#### Real-time Monitoring
```bash
# Monitor system vitals
tail -f ~/rpi_vitals.log

# View continuous monitoring
tail -f ~/continuous_monitoring.log

# Check system health
./scripts/monitoring/system-health-check.sh
```

#### Hardware Monitoring
```bash
# Check temperature
vcgencmd measure_temp

# Check memory usage
free -h

# Check disk space
df -h

# Monitor CPU usage
htop
```

### Hardware Control (reTerminal)

#### Button and Display Control
```bash
# Start multi-button handler
python3 scripts/hardware/multi_button_handler.py

# F1 dashboard handler
python3 scripts/hardware/f1_dashboard_handler.py

# Test hardware functionality
python3 -c "
import digitalio
import board
print('Hardware test: GPIO available')
"
```

## Service-Specific Operations

### Home Assistant

#### Basic Operations
- **Restart**: Supervisor → System → Restart
- **Check logs**: Supervisor → System → Logs
- **Add integrations**: Configuration → Integrations
- **Backup**: Supervisor → Backups → Create Backup

#### Command Line
```bash
# Access Home Assistant CLI
docker exec -it homeassistant /bin/bash

# Check Home Assistant logs
docker logs homeassistant

# Restart Home Assistant container
docker restart homeassistant
```

### InfluxDB Operations

#### Database Management
```bash
# Access InfluxDB CLI
docker exec -it influxdb influx

# Common commands in InfluxDB CLI:
> SHOW DATABASES
> USE smarthome
> SHOW MEASUREMENTS
> SELECT * FROM system_vitals LIMIT 10
> DROP SERIES FROM system_vitals WHERE host='old_host'
```

#### Backup Database
```bash
# Backup InfluxDB data
docker exec influxdb influxd backup -portable /tmp/backup
docker cp influxdb:/tmp/backup ./influxdb-backup-$(date +%Y%m%d)
```

### Grafana Operations

#### Dashboard Management
1. **Access**: http://localhost:3000
2. **Login**: admin / [your_password]
3. **Import dashboards**: + → Import
4. **Create alerts**: Alerting → Alert Rules

#### Common Tasks
```bash
# Backup Grafana settings
docker exec grafana grafana-cli admin export-dashboard > dashboard-backup.json

# Check Grafana logs
docker logs grafana

# Restart Grafana
docker restart grafana
```

### Pi-hole Operations

#### DNS Management
1. **Access Admin**: http://localhost/admin
2. **Block domains**: Domains → Add to Blacklist
3. **Whitelist domains**: Domains → Add to Whitelist
4. **Update blocklists**: Tools → Update Gravity

#### Command Line
```bash
# Pi-hole commands
docker exec pihole pihole status
docker exec pihole pihole -q google.com  # Query domain
docker exec pihole pihole -w google.com  # Whitelist domain
docker exec pihole pihole -b badsite.com # Blacklist domain
docker exec pihole pihole -g             # Update gravity
```

### MQTT Broker Operations

#### Test MQTT Connection
```bash
# Subscribe to test topic
docker exec mosquitto mosquitto_sub -h localhost -t test/topic

# Publish test message
docker exec mosquitto mosquitto_pub -h localhost -t test/topic -m "Hello World"

# Check MQTT logs
docker logs mosquitto
```

## Maintenance Tasks

### Regular Maintenance (Weekly)

#### System Updates
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
docker-compose pull
docker-compose up -d

# Clean unused Docker resources
docker system prune -f
```

#### Log Management
```bash
# Rotate system logs
sudo logrotate -f /etc/logrotate.conf

# Clean application logs
> ~/rpi_vitals.log
> ~/continuous_monitoring.log

# Check log sizes
du -sh /var/log/*
```

#### Health Checks
```bash
# Run system health check
./scripts/monitoring/system-health-check.sh

# Check disk space
df -h

# Check memory usage
free -h

# Verify all services
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Monthly Maintenance

#### Security Updates
```bash
# Full system update
sudo apt update && sudo apt full-upgrade -y

# Update Docker
curl -fsSL https://get.docker.com | sudo sh

# Check for security vulnerabilities
sudo apt install -y lynis
sudo lynis audit system
```

#### Backup Verification
```bash
# Test backup integrity
./scripts/backup/backup-manager.sh verify

# Create full system backup
./scripts/backup/create-master-backup.sh

# Store backup off-site (recommended)
```

## Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check service logs
docker logs <service_name>

# Check system resources
free -h
df -h

# Restart service
docker-compose restart <service_name>
```

#### High Memory Usage
```bash
# Check memory consumers
docker stats

# Restart heavy services
docker restart homeassistant grafana influxdb

# Clear system cache
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```

#### Network Issues
```bash
# Check DNS resolution
nslookup google.com 127.0.0.1

# Restart Pi-hole
docker restart pihole

# Check network connectivity
ping 8.8.8.8
```

#### Storage Issues
```bash
# Clean Docker data
docker system prune -a

# Clean logs
sudo journalctl --vacuum-size=100M

# Check large files
sudo find / -size +100M -ls 2>/dev/null
```

### Emergency Procedures

#### Complete System Recovery
```bash
# Stop all services
docker stop $(docker ps -q)

# Restore from backup
./scripts/backup/restore-app-backup.sh [backup_file]

# Restart services
./scripts/system/manage-services.sh start
```

#### Factory Reset Services
```bash
# Remove all Docker data (DESTRUCTIVE!)
docker-compose down -v
docker system prune -a --volumes

# Redeploy from backup
./scripts/backup/restore-app-backup.sh [latest_backup]
```

## Performance Optimization

### System Tuning
```bash
# Increase swap if needed
sudo dphys-swapfile swapoff
sudo sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=512/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# Optimize SD card performance
echo 'tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100m 0 0' | sudo tee -a /etc/fstab
```

### Service Optimization
```bash
# Restart services to clear memory leaks
docker-compose restart

# Monitor resource usage
docker stats --no-stream

# Optimize InfluxDB retention
docker exec -it influxdb influx
> ALTER RETENTION POLICY autogen ON smarthome DURATION 30d
```

## Advanced Usage

### Custom Automations
- Create Home Assistant automations via web UI
- Use MQTT for custom IoT device integration
- Setup Grafana alerts for system monitoring

### API Access
- Home Assistant API: http://localhost:8123/api/
- InfluxDB API: http://localhost:8086/query
- Pi-hole API: http://localhost/admin/api.php

### Integration Examples
```python
# Python example: Send data to InfluxDB
import requests
data = "system_vitals,host=rpi temperature=25.5"
requests.post("http://localhost:8086/write?db=smarthome", data=data)
```

## Getting Help

1. **Check logs**: Always start with service logs
2. **System health**: Use monitoring scripts
3. **Documentation**: Refer to service-specific docs
4. **Community**: Home Assistant community forum
5. **Issues**: GitHub repository issues page
