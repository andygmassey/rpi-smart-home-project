#!/bin/bash
set -e

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="reTerminal_SmartHome_${BACKUP_DATE}"

echo "=== reTerminal Full SD Card Backup ==="
echo "Date: $(date)"
echo "Backup name: ${BACKUP_NAME}"
echo ""

# Check if we have enough space
REQUIRED_SPACE_GB=30
AVAILABLE_SPACE_GB=$(df /tmp | tail -1 | awk '{print int($4/1024/1024)}')

if [ $AVAILABLE_SPACE_GB -lt $REQUIRED_SPACE_GB ]; then
    echo "⚠️  Warning: You may not have enough space for a full backup"
    echo "Required: ~${REQUIRED_SPACE_GB}GB, Available: ${AVAILABLE_SPACE_GB}GB"
    echo ""
fi

# Stop non-critical services to reduce activity during backup
echo "📊 Stopping services temporarily for clean backup..."
~/manage-services.sh uptime-stop 2>/dev/null || true
~/manage-services.sh grafana-stop 2>/dev/null || true

sleep 3

echo "💾 Creating full SD card image..."
echo "This will take 15-30 minutes depending on SD card speed..."
echo ""

# Create the backup directory
mkdir -p ~/backups

# Create compressed image
sudo dd if=/dev/mmcblk0 bs=4M status=progress | gzip -c > ~/backups/${BACKUP_NAME}.img.gz

# Calculate checksums
echo ""
echo "🔐 Calculating checksums..."
cd ~/backups
sha256sum ${BACKUP_NAME}.img.gz > ${BACKUP_NAME}.img.gz.sha256

# Restart services
echo ""
echo "🔄 Restarting services..."
~/manage-services.sh uptime-start 2>/dev/null || true
~/manage-services.sh grafana-start 2>/dev/null || true

echo ""
echo "✅ Backup complete!"
echo "📁 Location: ~/backups/${BACKUP_NAME}.img.gz"
echo "🔐 Checksum: ~/backups/${BACKUP_NAME}.img.gz.sha256"
echo "📏 Size: $(ls -lh ~/backups/${BACKUP_NAME}.img.gz | awk '{print $5}')"
echo ""
echo "To restore this backup:"
echo "1. Flash to new SD card: gunzip -c ${BACKUP_NAME}.img.gz | sudo dd of=/dev/sdX bs=4M status=progress"
echo "2. Insert into reTerminal and boot"
echo ""
