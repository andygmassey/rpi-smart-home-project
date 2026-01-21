# Pi-hole Coordinated Watchdog System

**Created**: January 21, 2026
**Purpose**: Bulletproof, self-healing Pi-hole with no watchdog conflicts

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    COORDINATED WATCHDOG LAYERS                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  LAYER 1: Docker Restart Policy                                      │
│  ├── Trigger: Container exits/crashes                                │
│  ├── Action: Immediate restart                                       │
│  ├── Config: restart: unless-stopped                                 │
│  └── Limit: Built-in exponential backoff                            │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  LAYER 2: Smart Watchdog Script (pihole-watchdog.sh)                │
│  ├── Trigger: Container running but unhealthy (DNS not responding)  │
│  ├── Checks: DNS response, memory usage, database size              │
│  ├── Cooldown: 5 minutes between restarts                           │
│  ├── Limit: Max 3 restarts per hour                                 │
│  └── Escalation: Cleanup → Soft restart → Hard restart → Alert      │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  LAYER 3: Systemd Service (pihole-docker.service)                   │
│  ├── Trigger: System boot                                            │
│  ├── Action: Start docker-compose                                    │
│  └── Note: Does NOT monitor health (that's Layer 2's job)           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Why Three Layers?

| Scenario | Which Layer Handles It |
|----------|------------------------|
| Container crashes (segfault, OOM kill) | Layer 1 (Docker) |
| Container running but DNS frozen | Layer 2 (Watchdog) |
| System reboots | Layer 3 (Systemd) |
| Memory pressure building | Layer 2 (Watchdog runs cleanup) |
| Database growing too large | Layer 2 (Watchdog sends alert) |

---

## Files

| File | Location | Purpose |
|------|----------|---------|
| `pihole-watchdog.sh` | `~/pihole-watchdog.sh` | Smart watchdog script |
| `pihole-watchdog.service` | `/etc/systemd/system/` | Systemd service unit |
| `pihole-watchdog.timer` | `/etc/systemd/system/` | Runs watchdog every 2 min |
| `pihole-watchdog.log` | `~/pihole-watchdog.log` | Watchdog log file |
| `pihole-alerts.log` | `~/pihole-alerts.log` | Critical alerts log |
| `.pihole-watchdog-state` | `~/.pihole-watchdog-state` | Cooldown state tracking |

---

## Configuration (in pihole-watchdog.sh)

```bash
DNS_TIMEOUT=5                    # Seconds to wait for DNS response
MAX_DB_SIZE_MB=500               # Alert if database exceeds this
MEMORY_CRITICAL_PERCENT=90       # Run cleanup if memory exceeds this
MAX_RESTARTS_PER_HOUR=3          # Prevent restart storms
COOLDOWN_SECONDS=300             # 5 minutes between restart attempts
```

---

## How It Works

### Normal Operation
1. Timer triggers watchdog every 2 minutes
2. Watchdog checks: container running? DNS responding? Memory OK? DB size OK?
3. All checks pass → log "OK" and exit
4. Issue detected → take appropriate action

### When DNS Stops Responding
1. Watchdog detects DNS timeout
2. Checks cooldown (was there a recent restart?)
3. If cooldown OK: runs memory cleanup first
4. Performs soft restart (`docker compose restart`)
5. Waits 5 seconds, re-checks DNS
6. If still broken: performs hard restart (`down` + `up`)
7. Records restart time (for cooldown tracking)

### Restart Storm Prevention
- Minimum 5 minutes between any restart attempts
- Maximum 3 restarts per hour
- If limit reached: logs error, sends alert, stops trying
- Requires manual intervention (prevents infinite loops)

---

## Commands

### Check watchdog status
```bash
# View recent logs
tail -50 ~/pihole-watchdog.log

# Check timer status
systemctl status pihole-watchdog.timer

# Check last run
systemctl status pihole-watchdog.service
```

### Run watchdog manually
```bash
~/pihole-watchdog.sh
```

### View alerts
```bash
cat ~/pihole-alerts.log
```

### Reset cooldown state (after manual fix)
```bash
rm ~/.pihole-watchdog-state
```

### Disable watchdog temporarily
```bash
sudo systemctl stop pihole-watchdog.timer
```

### Re-enable watchdog
```bash
sudo systemctl start pihole-watchdog.timer
```

---

## Logs

### Watchdog log format
```
[2026-01-21 14:30:00] [INFO] === Pi-hole Watchdog Check ===
[2026-01-21 14:30:00] [OK] Container running
[2026-01-21 14:30:01] [OK] DNS responding
[2026-01-21 14:30:01] [OK] Memory OK: 45%
[2026-01-21 14:30:01] [OK] Database size OK: 91MB
[2026-01-21 14:30:01] [OK] All checks passed
[2026-01-21 14:30:01] [INFO] === Check Complete ===
```

### When issues are detected
```
[2026-01-21 14:32:00] [INFO] === Pi-hole Watchdog Check ===
[2026-01-21 14:32:00] [OK] Container running
[2026-01-21 14:32:05] [ERROR] DNS not responding
[2026-01-21 14:32:05] [INFO] Running memory cleanup...
[2026-01-21 14:32:06] [INFO] Memory cleanup complete
[2026-01-21 14:32:06] [WARN] Performing soft restart of Pi-hole...
[2026-01-21 14:32:16] [INFO] Restart recorded. Count this hour: 1/3
[2026-01-21 14:32:16] [INFO] Soft restart complete
[2026-01-21 14:32:21] [OK] DNS responding
[2026-01-21 14:32:21] [WARN] Issues detected: dns_not_responding
[2026-01-21 14:32:21] [INFO] === Check Complete ===
```

---

## Troubleshooting

### Watchdog keeps restarting Pi-hole
1. Check the actual issue: `docker logs pihole`
2. Check database size: `ls -lh ~/pihole-docker/etc-pihole/pihole-FTL.db`
3. Check memory: `free -h`
4. Fix root cause, then reset state: `rm ~/.pihole-watchdog-state`

### Watchdog stopped trying (limit reached)
1. Check alerts: `cat ~/pihole-alerts.log`
2. Fix the underlying issue
3. Reset state: `rm ~/.pihole-watchdog-state`
4. Restart manually: `cd ~/pihole-docker && docker compose up -d`

### Watchdog not running
```bash
# Check timer
systemctl status pihole-watchdog.timer

# Enable if disabled
sudo systemctl enable --now pihole-watchdog.timer
```

---

## What's Different From Before (Dec 2025)

| Before (Broken) | After (Coordinated) |
|-----------------|---------------------|
| 4 watchdogs fighting | 3 layers with clear responsibilities |
| No cooldowns | 5 min cooldown, 3/hour limit |
| No escalation | Cleanup → Soft → Hard → Alert |
| No logging | Full logging with state tracking |
| Immediate restarts | Memory cleanup before restart |
| No resource limits | 256MB memory limit on container |
| 1.4GB database | 7-day retention (91MB) |
| 512MB swap | 2GB swap |

---

## Future Enhancements (Optional)

- [ ] Add webhook/email notifications for alerts
- [ ] Add Grafana dashboard for watchdog metrics
- [ ] Add automatic database cleanup when size exceeds threshold
- [ ] Add network connectivity check (not just localhost DNS)
