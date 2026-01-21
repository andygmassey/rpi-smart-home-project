# reTerminal Smart Home - Remediation Plan

## Executive Summary

The live system and repository have significantly diverged. The repo is cloned on the device but not used - services run from separate directories with hardcoded configurations. This plan will:

1. Sync the repo to match the live (working) system
2. Restructure to use the repo as the single source of truth
3. Fix security, consistency, and maintainability issues
4. Re-enable Pi-hole with proper safeguards

---

## Phase 1: Capture Live State into Repository

**Goal**: Make the repo reflect what's actually running (and working).

### 1.1 Add systemd service files to repo
```
system/systemd/
├── grafana-influx.service
├── homepage-dashboard.service
├── mqtt-broker.service
├── network-monitor.service
├── pihole-docker.service
├── pihole-webhook.service
└── uptime-kuma.service
```

### 1.2 Update docker-compose files with live configs
- Copy working configs from `~/grafana-influx/`, `~/pihole-docker/`, etc.
- But convert hardcoded passwords → environment variables

### 1.3 Add missing scripts to repo
Scripts currently in `~/` that should be in `scripts/`:
- `memory_cleanup.sh`
- `log_monitor.sh`
- `getflix-update.sh`
- `safe-backup.sh` / `safe-backup-auto.sh`
- `launch-homepage-kiosk.sh`
- `cleanup_database.sh`

### 1.4 Add incident documentation
- Move `PIHOLE_INCIDENT_REPORT.md` to `docs/incidents/`
- Move `DISASTER_RECOVERY_GUIDE.md` to `docs/`
- Move `STABILITY_REPORT.md` to `docs/`

---

## Phase 2: Security & Configuration Cleanup

### 2.1 Remove hardcoded credentials
**Files to fix:**
- `scripts/system/manage-services.sh` - Remove `(admin/admin123)` display
- All docker-compose files - Use `${VAR:-default}` pattern

### 2.2 Create comprehensive .env.example
```env
# Timezone (used by all services)
TZ=Asia/Hong_Kong

# InfluxDB
INFLUXDB_ADMIN_USER=admin
INFLUXDB_ADMIN_PASS=changeme
INFLUXDB_USER=grafana
INFLUXDB_USER_PASS=changeme

# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASS=changeme

# MQTT (if auth enabled)
MQTT_USER=homeassistant
MQTT_PASS=changeme

# Network
DEVICE_IP=192.168.1.76
```

### 2.3 Parameterize IP addresses
Replace all `192.168.1.76` with `${DEVICE_IP}` or use `localhost` where appropriate.

### 2.4 Standardize timezone
All services should use `TZ=${TZ:-Asia/Hong_Kong}`.

---

## Phase 3: Restructure for Single Source of Truth

### 3.1 New directory structure
```
rpi-smart-home-project/
├── docker/                    # Docker Compose services
│   ├── grafana-influx/
│   ├── homepage/
│   ├── mqtt-broker/
│   ├── pihole/
│   └── uptime-kuma/
├── scripts/
│   ├── backup/
│   ├── hardware/
│   ├── monitoring/
│   ├── system/
│   └── maintenance/           # NEW: memory_cleanup, log_monitor, etc.
├── system/                    # NEW: System-level configs
│   ├── systemd/               # Service unit files
│   ├── cron/                  # Crontab exports
│   └── logrotate/             # Log rotation configs
├── docs/
│   ├── incidents/             # Post-mortems
│   └── runbooks/              # Operational procedures
├── .env.example
├── deploy.sh                  # NEW: Unified deployment script
├── CLAUDE.md
└── README.md
```

### 3.2 Create unified deployment script
A single `deploy.sh` that:
1. Copies docker directories to `~/`
2. Installs systemd services
3. Sets up cron jobs
4. Validates configuration

### 3.3 Create symlink-based deployment (alternative)
Instead of copying, symlink from `~/*` to repo directories:
```bash
ln -s ~/rpi-smart-home-project/docker/grafana-influx ~/grafana-influx
```

---

## Phase 4: Pi-hole Recovery

### 4.1 Root cause mitigations
Based on the incident report:

1. **Database size management**
   - Add cron job to trim Pi-hole database weekly
   - Set `MAXDBDAYS=7` in Pi-hole config

2. **Memory protection**
   - Increase swap to 2GB (already done per report)
   - Add memory limits to docker-compose:
     ```yaml
     deploy:
       resources:
         limits:
           memory: 512M
     ```

3. **Backup timing**
   - Don't run backups while Pi-hole is under load
   - Stop Pi-hole before backup, restart after

### 4.2 Re-enable Pi-hole
```yaml
# docker-compose.yml changes
restart: unless-stopped  # was: "no"
healthcheck:
  test: ["CMD", "dig", "+norecurse", "+retry=0", "@127.0.0.1", "pi.hole"]
  interval: 30s
  timeout: 10s
  retries: 3
```

### 4.3 Add Pi-hole watchdog
Script to monitor and auto-recover Pi-hole if it crashes.

---

## Phase 5: Code Quality

### 5.1 Remove duplicate files
- Delete `scripts/hardware/f1_dashboard_handler.py` (superseded by multi_button_handler.py)

### 5.2 Pin Docker image versions
```yaml
# Instead of:
image: pihole/pihole:latest

# Use:
image: pihole/pihole:2024.07.0
```

### 5.3 Add basic validation
- GitHub Actions workflow to validate docker-compose files
- Pre-commit hook for secrets detection

---

## Implementation Order

### Week 1: Stabilization
1. [ ] Capture systemd services into repo
2. [ ] Update docker-compose files (security fixes)
3. [ ] Create comprehensive .env.example
4. [ ] Test on live system

### Week 2: Restructure
5. [ ] Reorganize directory structure
6. [ ] Create deploy.sh script
7. [ ] Move scripts to proper locations
8. [ ] Update documentation

### Week 3: Pi-hole Recovery
9. [ ] Implement database trimming
10. [ ] Add memory limits
11. [ ] Re-enable Pi-hole with safeguards
12. [ ] Monitor for 48 hours

### Week 4: Polish
13. [ ] Pin all Docker versions
14. [ ] Add CI validation
15. [ ] Clean up old files on live system
16. [ ] Final documentation update

---

## Rollback Plan

If any phase causes issues:

1. **Services broken**: Restore from `~/backups/` using existing restore script
2. **Pi-hole unstable**: Disable service again: `sudo systemctl disable pihole-docker`
3. **Repo changes problematic**: `git checkout HEAD~1` on both local and device

---

## Success Criteria

- [ ] Repo is the single source of truth
- [ ] `git pull && ./deploy.sh` updates live system
- [ ] No hardcoded passwords in repo
- [ ] All services running including Pi-hole
- [ ] System stable for 1 week post-changes
