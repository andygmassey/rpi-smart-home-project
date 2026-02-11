# Installation Guide

Complete setup instructions for the Raspberry Pi Smart Home System.

## Prerequisites

### Hardware Requirements
- Raspberry Pi CM4 with reTerminal display
- MicroSD card or eMMC (32GB+ recommended)
- Stable internet connection
- Power supply (USB-C, 5V/3A minimum)

### Software Requirements
- Raspberry Pi OS (Debian-based)
- Docker and Docker Compose
- Git
- Python 3.x

## Step 1: Basic System Setup

### Update System
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install git curl wget vim nano -y
```

### Install Docker
```bash
# Download and install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo apt install docker-compose -y

# Verify installation
docker --version
docker-compose --version
```

### Enable Docker at Boot
```bash
sudo systemctl enable docker
```

## Step 2: Clone Repository

```bash
cd ~
git clone https://github.com/andygYOUR_USERNAME/rpi-smart-home-project.git
cd rpi-smart-home-project
```

## Step 3: Environment Configuration

### Create Environment Files
```bash
# Copy environment template
cp .env.example .env

# Edit with your secure passwords
nano .env
```

**Required environment variables:**
```env
# InfluxDB Configuration
INFLUXDB_ADMIN_PASS=your_secure_admin_password
INFLUXDB_USER_PASS=your_secure_user_password

# Grafana Configuration  
GRAFANA_ADMIN_PASS=your_secure_grafana_password

# MQTT Configuration
MQTT_USER=your_mqtt_username
MQTT_PASS=your_secure_mqtt_password
```

## Step 4: Install Home Assistant

### Install Home Assistant Supervised
```bash
# Install dependencies
sudo apt install \
  apparmor \
  bluez \
  cifs-utils \
  curl \
  dbus \
  jq \
  libglib2.0-bin \
  lsb-release \
  network-manager \
  nfs-common \
  systemd-journal-remote \
  systemd-resolved \
  udisks2 \
  wget -y

# Install Home Assistant Supervised
wget -O homeassistant-supervised.deb https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb
sudo apt install ./homeassistant-supervised.deb
```

### Wait for Installation
Home Assistant takes 10-20 minutes to install. Monitor with:
```bash
sudo journalctl -fu hassio-supervisor
```

Access at: http://localhost:8123

## Step 5: Deploy Docker Services

### Start Core Monitoring Stack
```bash
cd docker/grafana-influx
docker-compose up -d
```

### Start Network Services  
```bash
cd ../pihole
docker-compose up -d

cd ../mqtt-broker
docker-compose up -d
```

### Start Dashboard and Monitoring
```bash
cd ../homepage
docker-compose up -d

cd ../uptime-kuma
docker-compose up -d
```

### Start Network Monitoring
```bash
cd ../fing-agent-network
docker-compose up -d
```

## Step 6: Configure Services

### InfluxDB Setup
```bash
# Create database
docker exec -it influxdb influx
> CREATE DATABASE smarthome
> CREATE USER "grafana" WITH PASSWORD "your_password"
> GRANT ALL ON smarthome TO grafana
> exit
```

### Configure Grafana
1. Access: http://localhost:3000
2. Login: admin / (your_grafana_password)
3. Add InfluxDB data source:
   - URL: http://influxdb:8086
   - Database: smarthome
   - User: grafana

### Configure Pi-hole
1. Access: http://localhost/admin
2. Set admin password:
   ```bash
   docker exec -it pihole pihole -a -p your_password
   ```

## Step 7: Install System Scripts

### Make Scripts Executable
```bash
chmod +x scripts/*/*.sh
chmod +x scripts/*/*.py
```

### Install System Health Monitor
```bash
sudo cp scripts/monitoring/rpi_vitals_monitor.sh /usr/local/bin/
sudo cp /usr/local/bin/system-health-monitor.sh /usr/local/bin/ # If not exists
```

### Setup Cron Jobs
```bash
# Add monitoring cron job
crontab -e
# Add this line:
* * * * * /usr/local/bin/rpi_vitals_monitor.sh >> ~/rpi_vitals.log 2>&1
```

## Step 8: Hardware Setup (reTerminal)

### Install Python Dependencies
```bash
sudo apt install python3-pip python3-gpiozero -y
pip3 install RPi.GPIO seeed-python-reterminal
```

### Setup Hardware Scripts
```bash
# Make hardware scripts executable
chmod +x scripts/hardware/*.py

# Test hardware scripts
python3 scripts/hardware/multi_button_handler.py
```

## Step 9: Kiosk Mode (Optional)

### Install Chromium
```bash
sudo apt install chromium-browser -y
```

### Setup Kiosk Scripts
```bash
chmod +x scripts/system/launch-ha-kiosk.sh
chmod +x scripts/system/control-kiosk.sh

# Test kiosk mode
./scripts/system/launch-ha-kiosk.sh
```

## Step 10: Backup System

### Setup Backup Scripts
```bash
chmod +x scripts/backup/*.sh

# Test backup system
./scripts/backup/backup-manager.sh --help
```

### Schedule Automated Backups
```bash
sudo crontab -e
# Add backup schedule (example: weekly backup)
0 2 * * 0 /home/$(whoami)/rpi-smart-home-project/scripts/backup/create-app-backup.sh
```

## Step 11: Network Configuration

### Configure Router DNS (Optional)
Set your router's primary DNS to your Pi's IP address to use Pi-hole network-wide.

### Configure Static IP (Recommended)
```bash
sudo nano /etc/dhcpcd.conf
# Add:
# interface eth0
# static ip_address=192.168.1.100/24
# static routers=192.168.1.1
# static domain_name_servers=127.0.0.1
```

## Step 12: Verification

### Check All Services
```bash
docker ps
```

All services should show "Up" status.

### Test Web Interfaces
- Home Assistant: http://localhost:8123
- Grafana: http://localhost:3000  
- Pi-hole: http://localhost/admin
- Uptime Kuma: http://localhost:3001
- Homepage: http://localhost:3000

### Check System Health
```bash
./scripts/monitoring/system-health-check.sh
```

## Troubleshooting

### Service Issues
```bash
# Check logs
docker logs <service_name>

# Restart service
docker-compose restart <service_name>

# Check system resources
free -h
df -h
```

### Home Assistant Issues
```bash
# Check supervisor logs
sudo journalctl -fu hassio-supervisor

# Restart Home Assistant
sudo systemctl restart hassio-supervisor
```

### Network Issues
```bash
# Check Pi-hole logs
docker logs pihole

# Test DNS resolution
nslookup google.com 127.0.0.1
```

## Post-Installation

1. **Configure Home Assistant** integrations and automations
2. **Setup Grafana dashboards** for system monitoring
3. **Configure Pi-hole** block lists and whitelists  
4. **Test backup and restore** procedures
5. **Setup alerts** in Uptime Kuma
6. **Customize Homepage** dashboard

## Security Hardening

1. Change default passwords for all services
2. Enable fail2ban: `sudo apt install fail2ban`
3. Configure firewall: `sudo ufw enable`
4. Regular updates: `sudo apt update && sudo apt upgrade`
5. Monitor logs regularly

## Support

For issues, check:
1. Service logs: `docker logs <service_name>`
2. System logs: `sudo journalctl -xf`
3. GitHub repository issues
4. Home Assistant community forum
