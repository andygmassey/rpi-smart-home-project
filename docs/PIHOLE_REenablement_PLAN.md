# Pi-hole Safe Re-enablement Plan

**Created**: January 21, 2026
**Last Incident**: December 3-4, 2025 (7 weeks ago)
**Risk Level**: Low (all root causes addressed)

---

## Pre-Flight Checklist

Before re-enabling, verify:

- [x] Database size < 100MB (currently 91MB)
- [x] MAXDBDAYS=7 configured
- [x] Swap = 2GB
- [x] Available memory > 1GB (currently 2.6GB)
- [x] Watchdogs disabled
- [x] DNS config fixed (no 127.0.0.1)
- [x] Safe backup script exists
- [ ] Router DNS NOT pointing to reTerminal yet

---

## Phase 1: Start Pi-hole (Manual, No Auto-restart)

**Goal**: Verify Pi-hole starts and runs stable for 10+ minutes

```bash
# SSH to reTerminal
ssh YOUR_USERNAME@YOUR_DEVICE_IP

# Start Pi-hole manually (no restart policy)
cd ~/pihole-docker
docker compose up -d

# Watch logs for 2-3 minutes
docker logs -f pihole

# In another terminal, check stability
watch -n 5 'docker ps | grep pihole; free -h | grep Mem'
```

**Success criteria**:
- Container stays "Up" for 10+ minutes
- No restart loops in logs
- Memory usage stable
- DNS responds: `dig @127.0.0.1 google.com`

**If it fails**:
```bash
docker compose down
# We're back to current state, no harm done
```

---

## Phase 2: Test DNS Resolution (Local Only)

**Goal**: Verify DNS works without affecting network

```bash
# Test DNS resolution locally
dig @127.0.0.1 google.com
dig @127.0.0.1 facebook.com

# Test ad-blocking
dig @127.0.0.1 ads.google.com
# Should return 0.0.0.0

# Check Pi-hole web interface
curl -s http://localhost/admin/ | head -20
```

**Success criteria**:
- DNS queries resolve
- Ad domains blocked
- Web interface accessible

---

## Phase 3: Run for 24 Hours (Monitoring)

**Goal**: Confirm stability over time

```bash
# Leave running overnight
# Check next day:

# Verify still running
docker ps | grep pihole

# Check for any restarts
docker inspect pihole --format='{{.RestartCount}}'
# Should be 0

# Check memory hasn't grown excessively
docker stats pihole --no-stream

# Check database size hasn't exploded
ls -lh ~/pihole-docker/etc-pihole/pihole-FTL.db
# Should still be < 200MB
```

**Success criteria**:
- 0 restarts in 24 hours
- Memory stable
- Database size stable

---

## Phase 4: Enable Auto-restart

**Goal**: Make Pi-hole survive reboots

```bash
# Edit docker-compose.yml
cd ~/pihole-docker
nano docker-compose.yml

# Change:
#   restart: "no"
# To:
#   restart: unless-stopped

# Also remove:
#   healthcheck:
#     disable: true

# Recreate container with new policy
docker compose up -d
```

---

## Phase 5: Configure Network to Use Pi-hole

**Goal**: Network-wide ad blocking

**Option A: Per-device (Safest)**
- Configure individual devices to use YOUR_DEVICE_IP as DNS
- Easy to revert per device

**Option B: Router DHCP (Network-wide)**
- Set router's DHCP to give out YOUR_DEVICE_IP as DNS
- Affects all devices
- If Pi-hole goes down, network DNS breaks

**Recommendation**: Start with Option A for a week, then move to Option B

---

## Phase 6: Enable Systemd Service (Optional)

**Goal**: Start Pi-hole on boot via systemd

```bash
# Only after 1+ week of stability
sudo systemctl enable pihole-docker.service
```

---

## Rollback Procedures

### If Pi-hole becomes unstable:

```bash
# Immediate stop
docker compose down

# Network continues working (uses router DNS)
```

### If you enabled router DNS and Pi-hole dies:

1. Access router admin (usually 192.168.1.1)
2. Change DNS back to automatic/8.8.8.8
3. Reboot router or wait for DHCP refresh

### Nuclear option:

```bash
# Disable everything Pi-hole related
docker compose down
sudo systemctl disable pihole-docker.service
# System returns to current (working) state
```

---

## Monitoring Checklist (First Week)

Daily checks:
- [ ] Pi-hole container running? `docker ps | grep pihole`
- [ ] Restart count still 0? `docker inspect pihole --format='{{.RestartCount}}'`
- [ ] Database < 200MB? `ls -lh ~/pihole-docker/etc-pihole/pihole-FTL.db`
- [ ] Memory reasonable? `free -h`

---

## Timeline

| Day | Action |
|-----|--------|
| 1 | Phase 1-2: Start manually, test locally |
| 2-3 | Phase 3: Monitor for 24-48 hours |
| 4 | Phase 4: Enable auto-restart |
| 5-7 | Monitor with auto-restart |
| 8+ | Phase 5: Consider network-wide DNS |
| 14+ | Phase 6: Consider systemd service |

---

## Emergency Contacts

If something goes wrong during off-hours:
1. SSH in and run: `docker compose down`
2. Network will use router DNS (192.168.1.1) automatically
3. Everything else keeps working

---

## What's Different This Time

| Before | After |
|--------|-------|
| 1.4GB database | 91MB + 7-day retention |
| 512MB swap | 2GB swap |
| DNS loop (127.0.0.1) | Direct to 8.8.8.8 |
| 4 watchdogs fighting | All disabled |
| Auto-restart on | Manual start first |
| Network dependent | Test locally first |
