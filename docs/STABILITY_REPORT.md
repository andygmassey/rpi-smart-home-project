# System Stability Report - December 3, 2025

## Root Causes Identified

### 1. **Pi-hole Database Growth (PRIMARY ISSUE)**
- Database size: **1.4 GB** with 23+ million rows
- Default retention: **unlimited** 
- Memory impact: Pi-hole-FTL process using 177MB RAM to manage huge DB
- **FIX APPLIED**: Set `MAXDBDAYS=7` in pihole-FTL.conf

### 2. **Insufficient Swap Space**
- Original: 512MB (too small for 4GB RAM system)
- **FIX APPLIED**: Increased to 2GB

### 3. **Desktop Memory Leak (lxpanel)**
- lxpanel grew to 506MB on Dec 1st, triggering desktop restart
- Currently at 44MB (just restarted at 13:04)
- Memory cleanup script monitoring and auto-restarting at 500MB threshold
- **STATUS**: Being monitored by existing script

### 4. **Zombie Processes**
- 5 zombie processes accumulating (chromium, wget, unclutter)
- Don't consume memory but indicate process management issues
- **STATUS**: Cleanup script kills chromium zombies every 6 hours

## Changes Made

✅ **Swap increased from 512MB → 2GB**
```bash
# Permanent change in /etc/dphys-swapfile
CONF_SWAPSIZE=2048
```

✅ **Pi-hole retention reduced to 7 days**
```bash
# Created /home/YOUR_USERNAME/pihole-docker/etc-pihole/pihole-FTL.conf
MAXDBDAYS=7
DBIMPORT=yes
```

✅ **Created database vacuum script**
- Location: `/home/YOUR_USERNAME/cleanup_database.sh`
- Run manually to shrink the 1.4GB database
- Will take several minutes to complete

## Immediate Next Steps

1. **Run database vacuum** (optional but recommended):
   ```bash
   ~/cleanup_database.sh
   ```
   This will shrink the 1.4GB database significantly.

2. **Monitor for next 24-48 hours**:
   ```bash
   watch -n 60 free -h
   ```

3. **Check Pi-hole memory after 1 week**:
   ```bash
   docker exec pihole du -h /etc/pihole/pihole-FTL.db
   ps aux | grep pihole-FTL
   ```

## Long-term Recommendations

### If issues persist:

1. **Disable desktop GUI** (saves ~400MB):
   ```bash
   sudo systemctl set-default multi-user.target
   sudo reboot
   ```

2. **Add memory limits to containers** in docker-compose:
   ```yaml
   pihole:
     mem_limit: 256m
   ```

3. **Consider upgrading to Pi 4 with 8GB RAM**

## Expected Improvements

- **Swap**: 4x increase provides cushion for memory spikes
- **Pi-hole**: Database will shrink to ~100-200MB over next 7 days
- **Memory pressure**: Should eliminate OOM killer events
- **Stability**: System should run without crashes

## Monitoring

Your existing memory_cleanup.sh script runs every 6 hours and monitors:
- lxpanel memory usage (restarts at 500MB)
- Swap usage (optimizes at 40%)
- Zombie processes (kills chromium)

Log file: `/var/log/memory_cleanup.log`

---

**Next Review**: Check system after 24 hours to verify stability

---

## 2026-01-21: Uptime Kuma False Alerts Fix

**Issue**: InfluxDB (and other services) showing "DOWN then UP" alerts every few hours.

**Root Cause**: All Uptime Kuma monitors had `maxretries = 0`, meaning a single failed check (e.g., momentary network hiccup like `ECONNRESET`) triggered an immediate DOWN alert. The next successful check 5 minutes later triggered an UP alert.

**Fix**: Updated all monitors to `maxretries = 3` via SQLite:
```bash
cd ~/uptime-kuma && docker compose stop
sudo sqlite3 data/kuma.db 'UPDATE monitor SET maxretries = 3 WHERE maxretries < 2;'
docker compose start
```

**Result**: Uptime Kuma now retries 3 times before alerting, eliminating false positives from transient network issues.
