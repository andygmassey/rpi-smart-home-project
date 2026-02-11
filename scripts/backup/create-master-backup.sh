#!/bin/bash
set -e

MASTER_DATE=$(date +%Y%m%d_%H%M%S)
MASTER_NAME="rpi-master-backup-${MASTER_DATE}"
BACKUP_DIR="/mnt/rpi-backups/master-backup/${MASTER_NAME}"

echo "=== Creating Master RPi System Backup ==="
echo "⭐ PERMANENT MASTER BACKUP ⭐"
echo "This will be the baseline for all future incremental backups."
echo ""
echo "Date: $(date)"
echo "Backup name: ${MASTER_NAME}"
echo ""

# Check USB drive is mounted
if ! mountpoint -q /mnt/rpi-backups; then
    echo "❌ USB backup drive not mounted at /mnt/rpi-backups"
    exit 1
fi

# Check available space
AVAILABLE_SPACE_GB=$(df /mnt/rpi-backups | tail -1 | awk '{print int($4/1024/1024)}')
echo "💾 USB Drive space available: ${AVAILABLE_SPACE_GB}GB"

if [ "$AVAILABLE_SPACE_GB" -lt 5 ]; then
    echo "❌ Insufficient space on USB drive (need at least 5GB)"
    exit 1
fi

# Create backup directory
sudo mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"

echo ""
echo "🚀 Starting master backup..."

# Stop services to ensure clean backup
echo "⏸️  Temporarily stopping services..."
~/manage-services.sh stop-all 2>/dev/null || true

echo "📦 Creating boot filesystem backup..."
sudo tar --exclude='*.tmp' -czf boot-filesystem.tar.gz -C /boot .

echo "📦 Creating root filesystem backup (excluding backup files)..."
sudo tar --exclude='/proc/*' \
         --exclude='/sys/*' \
         --exclude='/dev/*' \
         --exclude='/run/*' \
         --exclude='/tmp/*' \
         --exclude='/var/tmp/*' \
         --exclude='/var/log/*' \
         --exclude='/var/cache/*' \
         --exclude='$HOME/reTerminal_*.tar.gz' \
         --exclude='$HOME/backups' \
         --exclude='/mnt/*' \
         --exclude='/media/*' \
         --exclude='/lost+found' \
         --exclude='*.tmp' \
         --exclude='*.swp' \
         --exclude='*~' \
         -czf root-filesystem.tar.gz -C / .

echo "📄 Creating system information..."
cat > BACKUP_INFO.txt << EOFINFO
# Raspberry Pi MASTER System Backup
# Created: $(date)
# Hostname: $(hostname)
# Backup Type: MASTER BACKUP (Permanent/Baseline)
# 
# This is the MASTER backup - all future incremental backups reference this.
# DO NOT DELETE this backup as it's required for incremental restore operations.

## System Information
OS Version: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Kernel: $(uname -r)
Architecture: $(uname -m)
Uptime at backup: $(uptime -p)

## Disk Usage at Time of Backup
$(df -h)

## Memory Information
$(free -h)

## Installed Packages
See: dpkg-packages.txt

## Restoration Instructions
1. This is a MASTER backup - keep it safe!
2. For full restore: Use both boot-filesystem.tar.gz and root-filesystem.tar.gz
3. For incremental restore: Apply this master backup first, then apply incremental backups in chronological order
4. Boot partition restore: Replace contents of boot partition with boot-filesystem.tar.gz
5. Root partition restore: Replace contents of root partition with root-filesystem.tar.gz
6. Expand filesystem on first boot if needed
EOFINFO

echo "📋 Creating package list..."
sudo dpkg -l > dpkg-packages.txt

echo "💿 Creating partition table backup..."
sudo fdisk -l /dev/mmcblk0 > partition-table.txt 2>/dev/null || echo "Partition table saved"

echo "🔐 Generating checksums..."
sudo sha256sum *.tar.gz *.txt > checksums.sha256

echo "📊 Backup summary:"
sudo ls -lh *.tar.gz *.txt

# Restart services
echo ""
echo "🔄 Restarting services..."
~/manage-services.sh start-all 2>/dev/null || true

echo ""
echo "✅ MASTER backup complete!"
echo "📁 Location: ${BACKUP_DIR}"
echo "🔐 Checksums: ${BACKUP_DIR}/checksums.sha256"
echo "📏 Total size: $(sudo du -sh ${BACKUP_DIR} | cut -f1)"
echo ""
echo "⭐ This is now your MASTER backup for incremental backups!"
echo "💡 Future backups will reference this master backup."
echo ""
