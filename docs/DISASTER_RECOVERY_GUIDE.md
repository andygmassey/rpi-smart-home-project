# 🆘 reTerminal Disaster Recovery Guide

## Quick Reference
- **System**: Raspberry Pi Compute Module 4 in reTerminal
- **Storage**: 29GB eMMC (internal, not removable)
- **Latest Backup**: Check `/media/massey/RPI-BACKUP/`
- **Services**: Pi-hole, Home Assistant, Uptime Kuma, Grafana, InfluxDB, MQTT, Homepage

---

## 📦 What You Have Backed Up

### Full System Images (Gold Master)
**Location**: USB drive `/media/massey/RPI-BACKUP/`

Latest backups:
- `rpi-smarthome-goldmaster-20251203-*.img.gz` (Creating now - 20-40 mins)
- `rpi-smarthome-goldmaster-20250822-155243.img.gz` (9.2GB, August 22)

These are **complete bootable images** of the entire system.

---

## 🔧 How to Restore (Step-by-Step)

### If reTerminal Dies Completely:

#### Option 1: Flash to New reTerminal (Easiest)
```bash
# 1. On another computer, plug in the USB backup drive
# 2. Download Balena Etcher or use dd

# Using Balena Etcher (Windows/Mac/Linux):
# - Open Balena Etcher
# - Select the .img.gz file (it can flash compressed images directly)
# - Select the target device (reTerminal eMMC or SD card)
# - Click Flash

# Using dd on Linux/Mac:
gunzip -c rpi-smarthome-goldmaster-20251203-*.img.gz | \
  sudo dd of=/dev/YOUR_DEVICE bs=4M status=progress oflag=sync

# Replace YOUR_DEVICE with:
# - /dev/sda (if reTerminal in USB boot mode)
# - /dev/mmcblk0 (if using SD card on another Pi)
```

#### Option 2: Network Restore (If reTerminal Still Boots)
```bash
# 1. SSH into broken reTerminal
ssh massey@192.168.1.76

# 2. Stop all services
docker stop $(docker ps -q)

# 3. Restore from USB
sudo gunzip -c /media/massey/RPI-BACKUP/rpi-smarthome-goldmaster-*.img.gz | \
  sudo dd of=/dev/mmcblk0 bs=4M status=progress

# 4. Reboot
sudo reboot
```

---

## 🎯 After Restore - Verification Checklist

1. **System Boots**
   - Screen shows homepage dashboard in kiosk mode
   
2. **Network Services**
   ```bash
   # Check all containers are running:
   docker ps
   
   # Should see: pihole, homepage, uptime-kuma, grafana, 
   #             influxdb, mosquitto, homeassistant
   ```

3. **Access Services** (use reTerminal IP or 192.168.1.76):
   - Homepage: http://192.168.1.76:3000
   - Home Assistant: http://192.168.1.76:8123
   - Pi-hole: http://192.168.1.76:80/admin
   - Uptime Kuma: http://192.168.1.76:3001
   - Grafana: http://192.168.1.76:3002 (admin/admin123)

4. **DNS Working**
   ```bash
   # On any device, set DNS to 192.168.1.76
   # Visit any website - ads should be blocked
   ```

---

## 🔍 Troubleshooting After Restore

### Services Not Starting
```bash
# Check Docker
sudo systemctl status docker

# Restart all containers
cd /home/massey
for dir in pihole-docker uptime-kuma grafana-influx mqtt-broker homepage-dashboard; do
  cd ~/$dir && docker-compose up -d
done
```

### LCD Not Showing Dashboard
```bash
# Restart kiosk mode
killall chromium-browser
DISPLAY=:0 /home/massey/launch-homepage-kiosk.sh &
```

### Network Issues
```bash
# Check IP address
ip addr show eth0

# If different IP, update:
# - Pi-hole settings
# - DNS on other devices
# - Homepage configuration
```

---

## 📝 Making New Backups

### Quick Backup (Recommended Before Changes)
```bash
# Just service configs (fast - 2 minutes):
tar -czf ~/backup-configs-$(date +%Y%m%d).tar.gz \
  ~/pihole-docker/ \
  ~/uptime-kuma/ \
  ~/grafana-influx/ \
  ~/mqtt-broker/ \
  ~/homepage-dashboard/ \
  ~/fing-agent/
```

### Full System Backup (Monthly)
```bash
# Plug in USB drive labeled "RPI-BACKUP"
# Then run:
sudo /home/massey/create-goldmaster-backup-compressed.sh

# Takes 20-40 minutes, creates ~9GB file
# Monitor: tail -f /tmp/backup-*.log
```

---

## 💾 Backup Best Practices

1. **Keep USB drive unplugged** except during backups (prevents corruption)
2. **Make backup after major changes** (new services, config updates)
3. **Test restore once** to verify process works
4. **Keep old backup** until new one is verified
5. **Store USB drive safely** away from Pi (fire/theft protection)

---

## 🚨 Emergency Contacts & Resources

**Your Configuration**:
- Network: 192.168.1.x
- Swap: 2GB (upgraded Dec 3, 2025)
- Pi-hole: 7-day retention (upgraded Dec 3, 2025)

**Backup Locations**:
- USB: `/media/massey/RPI-BACKUP/`
- Scripts: `/home/massey/*.sh`
- Configs: `/home/massey/*/docker-compose.yml`

**Key Files**:
- This guide: `~/DISASTER_RECOVERY_GUIDE.md`
- Backup guide: `~/BACKUP_QUICK_GUIDE.md`
- Stability report: `~/STABILITY_REPORT.md`

---

## ✅ Current System Status (Dec 3, 2025)

- ✅ Memory issues fixed (swap 512MB→2GB)
- ✅ Pi-hole database reduced (1.4GB→7-day retention)
- ✅ LCD kiosk mode restored (Homepage dashboard)
- ✅ New backup created with all fixes
- ✅ All services stable

**Next backup due**: After this current backup completes


---

## ⚠️ IMPORTANT: Safe Backup Procedure (Updated Dec 3)

**The system crashed during backup due to memory pressure.**

### DO NOT use the direct backup command while system is running!

### ✅ SAFE METHOD: Use the new script
```bash
~/safe-backup.sh
```

This script:
1. Stops non-essential services (Homepage, Grafana, Uptime Kuma)
2. Frees memory
3. Runs backup
4. Restarts services automatically

**OR** manually stop more services:
```bash
# Stop everything except Pi-hole and Home Assistant
docker stop homepage grafana uptime-kuma influxdb mosquitto

# Run backup
sudo ~/create-goldmaster-backup-compressed.sh

# Restart when done
cd ~/homepage-dashboard && docker-compose up -d
cd ~/grafana-influx && docker-compose up -d
cd ~/uptime-kuma && docker-compose up -d
cd ~/mqtt-broker && docker-compose up -d
```

### Current Valid Backup
**Only use**: `rpi-smarthome-goldmaster-20250822-155243.img.gz` (9.2GB, August 22)

This backup does NOT include today's fixes (swap increase, Pi-hole config).
Those changes will persist through reboots but aren't in the backup image yet.

**To get today's fixes in a backup**: Run `~/safe-backup.sh` when convenient.

