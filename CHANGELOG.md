# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-03-22

### Fixed
- **UK VPN tunnel stability**: Unlocator server pushes aggressive keepalive settings (`ping 5, ping-restart 10`) that caused constant reconnects (~every 2-5 minutes) on the HK→London path. Added `pull-filter ignore "ping"` with local `ping 15, ping-restart 120` to uk-vpn.conf

### Changed
- **VPN docs updated**: Apple TV routing documentation now reflects two Apple TVs (192.168.1.21 Living Room, 192.168.1.31 Man Cave) on WiFi, replacing the old single-device reference
- **Network docs updated**: Apple TV connection type confirmed as WiFi (not wired)

---

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

[1.1.0]: https://github.com/andygmassey/rpi-smart-home-project/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/andygmassey/rpi-smart-home-project/releases/tag/v1.0.0
