# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-21

### 🎉 Initial Public Release

#### Added
- **Core Services**
  - Home Assistant Supervised integration
  - Grafana + InfluxDB monitoring stack with custom dashboards
  - Pi-hole DNS filtering with Unlocator SmartDNS support
  - Homepage unified dashboard
  - Uptime Kuma service monitoring
  - MQTT broker (Mosquitto) for IoT devices
  - Fing Agent network discovery

- **Hardware Integration**
  - reTerminal GPIO button handler (F1/F2/F3/O buttons)
  - Custom kiosk mode launcher for touchscreen display
  - VNC remote desktop support

- **Monitoring & Automation**
  - System vitals monitoring (CPU, memory, disk, network)
  - Real-time Grafana dashboards
  - Automated health checks and watchdog systems
  - Pi-hole 3-layer watchdog protection

- **Backup & Recovery**
  - Comprehensive backup system (app, system, full)
  - Automated backup scripts
  - Disaster recovery documentation
  - Safe backup workflows with service management

- **Network & Security**
  - VPN proxy system for selective traffic routing
  - Pi-hole webhook for temporary blocking pauses
  - Network-wide ad blocking
  - Custom DNS configuration

- **Documentation**
  - Complete installation guide
  - Usage documentation
  - Service overview and architecture
  - Incident reports and troubleshooting guides
  - Disaster recovery guide

#### Infrastructure
- Docker Compose orchestration for all services
- Systemd service management
- Environment variable configuration
- Automated deployment scripts
- Health monitoring and alerting

### 🔒 Security
- Removed sensitive data from repository
- Anonymized personal information
- Comprehensive .gitignore for secrets
- MIT License with third-party acknowledgments

---

## Release Notes Format

For future releases, use the following categories:

- **Added** for new features
- **Changed** for changes in existing functionality
- **Deprecated** for soon-to-be removed features
- **Removed** for now removed features
- **Fixed** for any bug fixes
- **Security** for vulnerability fixes

[1.0.0]: https://github.com/andygmassey/rpi-smart-home-project/releases/tag/v1.0.0
