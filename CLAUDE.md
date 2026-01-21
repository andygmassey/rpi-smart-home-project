# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A smart home automation system running on a SeeedStudio reTerminal (Raspberry Pi CM4) with integrated touchscreen display. The system runs multiple Docker services for home automation, monitoring, and network management.

**Live system**: `192.168.1.76` (SSH: `ssh massey@192.168.1.76`)

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              reTerminal Hardware                     │
│  (CM4 + 5" touchscreen + GPIO buttons F1/F2/F3/O)   │
├─────────────────────────────────────────────────────┤
│                 Kiosk Mode (Chromium)               │
├─────────────────────────────────────────────────────┤
│  Home Assistant │ Grafana:3002 │ Homepage:3000     │
│  (Supervised)   │ InfluxDB:8086│ Uptime Kuma:3001  │
│  :8123          │              │                    │
├─────────────────┼──────────────┼────────────────────┤
│  Pi-hole:80     │ MQTT:1883    │ Fing Agent        │
│  (DISABLED)     │ (Mosquitto)  │ (Network Scan)    │
├─────────────────────────────────────────────────────┤
│                   Docker Engine                      │
├─────────────────────────────────────────────────────┤
│              Raspberry Pi OS (Debian)               │
└─────────────────────────────────────────────────────┘
```

## Repository Structure

```
rpi-smart-home-project/
├── docker/                     # Docker Compose services
│   ├── grafana-influx/         # Monitoring stack (Grafana + InfluxDB)
│   ├── pihole/                 # DNS filtering (currently disabled)
│   ├── homepage/               # Dashboard aggregator
│   ├── uptime-kuma/            # Service availability monitoring
│   ├── mqtt-broker/            # Mosquitto MQTT broker
│   └── fing-agent-network/     # Network device discovery
├── scripts/
│   ├── hardware/               # reTerminal button handler
│   ├── system/                 # Service management, kiosk control
│   ├── backup/                 # Backup and restore automation
│   ├── monitoring/             # System vitals collection
│   └── maintenance/            # Memory cleanup, log management
├── system/
│   ├── systemd/                # Service unit files
│   └── cron/                   # Crontab configuration
├── docs/                       # Documentation and incident reports
├── monitoring/grafana-influx/  # Dashboard JSON and reference docs
├── .env.example                # Environment variables template
├── deploy.sh                   # Deployment script
└── rollback.sh                 # Rollback script
```

## Deployment

### First-time Setup
```bash
# On the reTerminal
cd ~/rpi-smart-home-project
cp .env.example .env
nano .env  # Set your actual passwords
./deploy.sh
```

### Deploying Changes
```bash
# From repo directory
./deploy.sh
# Select option 1 for full deployment, or specific components
```

### Rolling Back
```bash
# List available backups
ls ~/backups/

# Rollback to specific backup
./rollback.sh ~/backups/pre-deploy-20260121_160000
```

## Key Services

| Service | Port | Live Directory | Status |
|---------|------|----------------|--------|
| Home Assistant | 8123 | (Supervised) | Running |
| Grafana | 3002 | ~/grafana-influx | Running |
| InfluxDB | 8086 | ~/grafana-influx | Running |
| Homepage | 3000 | ~/homepage-dashboard | Running |
| Uptime Kuma | 3001 | ~/uptime-kuma | Running |
| MQTT | 1883 | ~/mqtt-broker | Running |
| Pi-hole | 80 | ~/pihole-docker | **Disabled** |

## Common Commands

### Service Management
```bash
# Check all services
~/manage-services.sh status

# Restart specific service
cd ~/grafana-influx && docker compose restart
```

### Hardware Button Handler
```bash
# Run button handler (F1=Grafana, F2=HA, F3=Pi-hole, O=Homepage)
python3 ~/multi_button_handler.py
```

### System Monitoring
```bash
# Manual vitals check (runs every minute via cron)
~/rpi_vitals_monitor.sh
```

### Backups
```bash
# Interactive backup manager
~/backup-manager.sh

# Quick app backup
~/create-app-backup.sh
```

## Environment Variables

All services use environment variables from `.env`. Key variables:
- `DEVICE_IP` - reTerminal's static IP (default: 192.168.1.76)
- `TZ` - Timezone (default: Asia/Hong_Kong)
- `INFLUXDB_ADMIN_PASS`, `INFLUXDB_USER_PASS` - Database credentials
- `GRAFANA_ADMIN_PASS` - Grafana admin password

## Pi-hole Status

**Currently disabled** after Dec 2025 OOM incident (see `docs/incidents/PIHOLE_INCIDENT_REPORT.md`).

To re-enable:
1. Edit `docker/pihole/docker-compose.yml`
2. Change `restart: "no"` to `restart: unless-stopped`
3. Remove `healthcheck: disable: true`
4. Deploy: `./deploy.sh`
5. Enable service: `sudo systemctl enable pihole-docker`

## Safety Notes

1. **Always backup before changes**: `./deploy.sh` creates automatic backups
2. **Rollback available**: `./rollback.sh <backup_path>`
3. **Pre-refactor backup**: `~/backups/pre-refactor-20260121.tar.gz` (85MB)
4. **Test with dry run**: `./deploy.sh` option 5

## Live System vs Repo Mapping

| Repo Path | Live Path |
|-----------|-----------|
| `docker/grafana-influx/` | `~/grafana-influx/` |
| `docker/pihole/` | `~/pihole-docker/` |
| `docker/homepage/` | `~/homepage-dashboard/` |
| `docker/mqtt-broker/` | `~/mqtt-broker/` |
| `docker/uptime-kuma/` | `~/uptime-kuma/` |
| `scripts/*/*.sh` | `~/*.sh` |
| `system/systemd/*.service` | `/etc/systemd/system/` |
