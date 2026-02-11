# Raspberry Pi Smart Home Project

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi-red.svg)](https://www.raspberrypi.com/)
[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?logo=docker&logoColor=white)](https://www.docker.com/)

A comprehensive smart home automation system running on Raspberry Pi CM4 with reTerminal display.

## 🏠 Overview

This project provides a complete smart home solution featuring real-time monitoring, automation, network management, and hardware control - all running in a secure, containerized environment.

### ✨ Key Features

- **🏡 Home Automation**: Home Assistant with full supervisor support
- **📊 Real-time Monitoring**: Grafana + InfluxDB with custom dashboards  
- **🌐 Network Management**: Pi-hole DNS filtering and MQTT broker
- **📱 Unified Dashboard**: Homepage with service overview
- **⚡ Service Monitoring**: Uptime Kuma for availability tracking
- **🔧 Hardware Control**: Custom Python scripts for reTerminal
- **💾 Automated Backups**: Comprehensive backup and restore system
- **🛡️ System Health**: Automated monitoring with email alerts
- **🎮 Kiosk Mode**: Full-screen display modes for dashboards

## 🏗️ System Architecture

### Services Stack
```
┌─────────────────────────────────────────────────┐
│                 reTerminal Display               │
│        (Hardware Controls & Kiosk Mode)         │
├─────────────────────────────────────────────────┤
│              Homepage Dashboard                 │
│         (Unified Service Overview)              │
├─────────────────────────────────────────────────┤
│  Home Assistant  │  Grafana    │  Pi-hole      │
│  (Automation)    │ (Analytics) │  (DNS/AdBlock)│
├──────────────────┼─────────────┼───────────────┤
│   InfluxDB       │ Uptime Kuma │ MQTT Broker   │
│ (Time Series DB) │ (Monitoring)│ (IoT Messages)│
├─────────────────────────────────────────────────┤
│              Docker Container Layer             │
├─────────────────────────────────────────────────┤
│           Raspberry Pi OS (Debian)              │
└─────────────────────────────────────────────────┘
```

### Hardware
- **Platform**: Raspberry Pi CM4 with reTerminal
- **Storage**: eMMC (no SD card dependencies)
- **Display**: Built-in touchscreen with custom controls
- **Connectivity**: Ethernet, WiFi, GPIO access

## 📋 Services Overview

| Service | Purpose | Web Interface | Port |
|---------|---------|---------------|------|
| **Home Assistant** | Automation Hub | http://YOUR_DEVICE_IP:8123 | 8123 |
| **Grafana** | Data Visualization | http://YOUR_DEVICE_IP:3002 | 3002 |
| **InfluxDB** | Metrics Database | - | 8086 |
| **Pi-hole** | DNS + Ad Blocking | http://YOUR_DEVICE_IP/admin | 80 |
| **Homepage** | Unified Dashboard | http://YOUR_DEVICE_IP:3002 | 3002 |
| **Uptime Kuma** | Service Monitoring | http://YOUR_DEVICE_IP:3001 | 3001 |
| **MQTT Broker** | IoT Messaging | - | 1883 |
| **Fing Agent** | Network Discovery | - | - |

## 🚀 Quick Start

### Prerequisites
- Raspberry Pi CM4 with reTerminal
- Docker and Docker Compose installed
- Git configured

### Installation
```bash
# Clone repository
git clone https://github.com/andygmassey/rpi-smart-home-project.git
cd rpi-smart-home-project

# Setup environment
cp .env.example .env
nano .env  # Configure your passwords

# Deploy services
./scripts/system/deploy-all-services.sh

# Access main dashboard
open http://YOUR_DEVICE_IP:3002
```

## 📚 Documentation

### 📖 Complete Guides
- **[🔧 Installation Guide](docs/INSTALLATION.md)** - Complete setup instructions
- **[📖 Usage Guide](docs/USAGE.md)** - Daily operations and maintenance
- **[🛠️ Services Overview](docs/SERVICES.md)** - Detailed service documentation

### 🗂️ Quick References
- **[🔧 Script Reference](#script-reference)** - All automation scripts
- **[🐳 Docker Services](#docker-services)** - Container configurations
- **[💾 Backup System](#backup-system)** - Data protection
- **[⚡ Hardware Control](#hardware-control)** - reTerminal integration

## 🗂️ Directory Structure

```
📁 rpi-smart-home-project/
├── 📁 scripts/
│   ├── 📁 backup/          # Backup and restore automation
│   ├── 📁 monitoring/      # System health and metrics
│   ├── 📁 system/          # Service management utilities  
│   └── 📁 hardware/        # reTerminal hardware control
├── 📁 docker/              # Docker Compose configurations
│   ├── 📁 grafana-influx/  # Monitoring stack
│   ├── 📁 pihole/          # DNS and ad-blocking
│   ├── 📁 homepage/        # Unified dashboard
│   ├── 📁 uptime-kuma/     # Service monitoring
│   ├── 📁 mqtt-broker/     # IoT messaging
├── 📁 docs/                # Comprehensive documentation
├── 📄 .env.example         # Environment configuration template
└── 📄 .gitignore          # Security-focused exclusions
```

## 🔧 Script Reference

### 💾 Backup Scripts (`scripts/backup/`)
- **`backup-manager.sh`** - Interactive backup management
- **`create-app-backup.sh`** - Application data backup
- **`create-master-backup.sh`** - Golden master backup  
- **`create-system-backup.sh`** - Full system backup
- **`backup-to-external.sh`** - External drive backup

### 📊 Monitoring Scripts (`scripts/monitoring/`)
- **`rpi_vitals_monitor.sh`** - System metrics collection
- **`continuous_monitoring.sh`** - 24/7 health monitoring
- **`timezone_monitoring_script.sh`** - Timezone change tracking

### ⚙️ System Scripts (`scripts/system/`)
- **`manage-services.sh`** - Docker service management
- **`launch-ha-kiosk.sh`** - Home Assistant kiosk mode
- **`control-kiosk.sh`** - Display control utilities
- **`setup-vnc-remote.sh`** - Remote access setup

### 🔧 Hardware Scripts (`scripts/hardware/`)
- **`multi_button_handler.py`** - reTerminal button control

## 🛡️ Pi-hole Watchdog System

Pi-hole provides network-wide DNS and ad-blocking with a bulletproof 3-layer watchdog system:

### Coordinated Protection Layers
| Layer | Responsibility | Mechanism |
|-------|---------------|-----------|
| **Layer 1** | Container crashes | Docker restart policy |
| **Layer 2** | Service unhealthy | Smart watchdog script (every 2 min) |
| **Layer 3** | System boot | Systemd service |

### Features
- **Cooldown Protection**: 5-minute minimum between restarts, max 3/hour
- **Escalation**: Cleanup → Soft restart → Hard restart → Alert
- **Unlocator SmartDNS**: Upstream DNS for geo-unblocking streaming services
- **Database Capped**: 7-day retention prevents runaway growth

See `docs/WATCHDOG_SYSTEM.md` for full documentation.


## 🐳 Docker Services

All services run in isolated Docker containers with persistent data storage:

### Core Stack
```bash
# Start monitoring stack
cd docker/grafana-influx && docker-compose up -d

# Start network services  
cd ../pihole && docker-compose up -d
cd ../mqtt-broker && docker-compose up -d

# Start dashboards
cd ../homepage && docker-compose up -d
cd ../uptime-kuma && docker-compose up -d
```

### Service Health
```bash
# Check all services
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Monitor resources
docker stats --no-stream
```

## 💾 Backup System

### Automated Backups
- **System Health Monitoring**: Every 6 hours with email alerts
- **Vitals Collection**: Every minute to InfluxDB
- **Application Backup**: Weekly automated backup
- **Configuration Backup**: Continuous Git versioning

### Manual Backup
```bash
# Quick application backup
./scripts/backup/create-app-backup.sh

# Full system backup
./scripts/backup/create-master-backup.sh

# Interactive backup manager
./scripts/backup/backup-manager.sh
```

### Restore Operations
```bash
# List available backups
ls ~/backups/

# Restore from backup
./scripts/backup/backup-manager.sh restore
```

## ⚡ Hardware Control

### reTerminal Integration
```bash
# Start button handler
python3 scripts/hardware/multi_button_handler.py

# Launch kiosk mode
./scripts/system/launch-ha-kiosk.sh

# Control display
./scripts/system/control-kiosk.sh [start|stop|restart]
```

### Hardware Features
- **Multi-button Control**: Custom actions for hardware buttons
- **Display Management**: Automatic brightness and power control
- **GPIO Integration**: Full access to Raspberry Pi GPIO
- **Touch Interface**: Direct touchscreen interaction

## 🛡️ Security Features

### Data Protection
- **🔐 Environment Variables**: No hardcoded passwords
- **🗂️ Comprehensive .gitignore**: Sensitive files excluded
- **🔒 Private Repository**: Code safely stored
- **🛡️ Container Isolation**: Services run in isolated containers

### Network Security
- **🌐 Pi-hole DNS Filtering**: Network-wide ad and malware blocking
- **🔒 Local Network Only**: No external dependencies required
- **📊 Traffic Monitoring**: Full network visibility

### System Monitoring
- **📊 Real-time Metrics**: System health dashboards
- **📧 Email Alerts**: Automated problem notifications  
- **📈 Historical Data**: Long-term performance tracking

## 📊 Monitoring & Alerts

### System Health Monitoring
The system automatically monitors:
- **Memory Usage**: Alerts at >90%
- **Swap Usage**: Alerts at >50% 
- **CPU Temperature**: Alerts at >80°C
- **Load Average**: Alerts at >8.0
- **Service Status**: Container health checks
- **Disk Space**: Storage monitoring

### Alert Destinations
- **Email Notifications**: Configurable SMTP alerts
- **Dashboard Alerts**: Grafana alert rules
- **Service Monitoring**: Uptime Kuma notifications

## 🔄 Development & Maintenance

### Version Control
```bash
# Make changes
git add .
git commit -m "Update configuration"
git push

# Create feature branch
git checkout -b new-feature
```

### Maintenance Tasks
```bash
# System updates
sudo apt update && sudo apt upgrade -y

# Docker cleanup
docker system prune -f

# Service restart
./scripts/system/manage-services.sh restart
```

## 🆘 Support & Troubleshooting

### Common Commands
```bash
# Check system health
./scripts/monitoring/system-health-check.sh

# View service logs
docker logs <service-name>

# Restart all services
./scripts/system/manage-services.sh restart

# Emergency backup
./scripts/backup/create-app-backup.sh
```

### Documentation
- **[📖 Full Installation Guide](docs/INSTALLATION.md)**
- **[📚 Complete Usage Guide](docs/USAGE.md)**  
- **[🛠️ Service Details](docs/SERVICES.md)**

### Getting Help
1. Check service logs: `docker logs <service>`
2. Run system health check: `./scripts/monitoring/system-health-check.sh`
3. Review documentation in `docs/` directory
4. Check GitHub issues for known problems

## 🏆 Project Status

**✅ Production Ready**
- All services deployed and monitored
- Comprehensive backup system active
- Full documentation complete
- Security hardening implemented
- Hardware integration functional

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Home Assistant Community** - Automation platform
- **Grafana Labs** - Visualization tools
- **Pi-hole Team** - Network filtering
- **Seeed Studio** - reTerminal hardware
- **Docker** - Containerization platform

---

**🏠 Built with ❤️ for Smart Home Automation**

*Last Updated: January 2026*

## Monitoring Stack

### Grafana + InfluxDB Setup
The `monitoring/grafana-influx/` directory contains a complete monitoring solution:

- **Grafana Dashboard**: System vitals visualization
- **InfluxDB Database**: Time-series metrics storage
- **Docker Compose**: Easy deployment

**Quick Start:**
```bash
cd monitoring/grafana-influx
# Edit docker-compose.yml to set your passwords
docker compose up -d
# Access: http://your-pi:3002
```

**Features:**
- Real-time CPU, memory, disk monitoring
- Temperature tracking
- Responsive dashboard design
- Secure authentication
- Automated log rotation

See [monitoring/grafana-influx/README.md](monitoring/grafana-influx/README.md) for detailed setup instructions.

## Recent Updates

### 2026-01-21: Major Infrastructure Overhaul

#### Pi-hole Re-enabled with Bulletproof Watchdog
- ✅ **Pi-hole Restored**: Re-enabled after 7 weeks offline (Dec 2025 OOM incident)
- ✅ **3-Layer Watchdog**: Coordinated Docker/Script/Systemd protection
- ✅ **Unlocator SmartDNS**: Configured for streaming geo-unblocking (185.37.37.37, 185.37.39.39)
- ✅ **Database Capped**: 7-day retention prevents growth issues

#### Security & Cleanup
- ✅ **Getflix VPN Removed**: Broken VPN infrastructure completely removed
- ✅ **Credentials Secured**: Removed all hardcoded passwords from scripts
- ✅ **IP Parameterized**: All hardcoded IPs replaced with environment variables

#### Backup System
- ✅ **Borg Backups**: Initialized and running every 2 weeks
- ✅ **Fresh Gold Master**: New disk image created (Jan 21, 2026)
- ✅ **Deploy/Rollback Scripts**: Safe deployment with automatic backups

#### Documentation
- ✅ **WATCHDOG_SYSTEM.md**: Full watchdog architecture documentation
- ✅ **PIHOLE_INCIDENT_REPORT.md**: Dec 2025 incident post-mortem
- ✅ **CLAUDE.md**: AI assistant context file

### 2025-08-31: System Maintenance
- ✅ Log rotation fixed
- ✅ Network monitoring optimized
- ✅ Grafana dashboard restored

