#!/bin/bash
set -e

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="reTerminal_eMMC_${BACKUP_DATE}"

echo "=== reTerminal eMMC System Backup ==="
echo "⚠️  eMMC cannot be removed like SD card!"
echo "This creates a compressed system image for network transfer."
echo ""
echo "Date: $(date)"
echo "Backup name: ${BACKUP_NAME}"
echo ""

# Check available space
REQUIRED_SPACE_GB=15
AVAILABLE_SPACE_GB=$(df /tmp | tail -1 | awk '{print int($4/1024/1024)}')

echo "💾 Storage check:"
echo "  eMMC size: $(lsblk /dev/mmcblk0 -o SIZE --noheadings | tr -d ' ')"
echo "  Used space: $(df -h / | tail -1 | awk '{print $3}')"
echo "  Available for backup: $(df -h /tmp | tail -1 | awk '{print $4}')"
echo ""

if [ $AVAILABLE_SPACE_GB -lt $REQUIRED_SPACE_GB ]; then
    echo "❌ Not enough space for full backup"
    echo "Required: ~${REQUIRED_SPACE_GB}GB, Available: ${AVAILABLE_SPACE_GB}GB"
    echo ""
    echo "🎯 RECOMMENDATION: Use application backup instead:"
    echo "   ~/backup-manager.sh app"
    exit 1
fi

# Warning about eMMC backup limitations
echo "⚠️  IMPORTANT - eMMC Backup Limitations:"
echo "   • Cannot clone to another device easily"
echo "   • Requires same hardware (reTerminal/CM4)" 
echo "   • Restore needs special tools (rpiboot, etc.)"
echo "   • Application backup is usually better"
echo ""

read -p "Continue with eMMC system backup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Backup cancelled"
    echo ""
    echo "💡 Try application backup instead:"
    echo "   ~/backup-manager.sh app"
    exit 1
fi

# Create backup directory  
mkdir -p ~/backups

echo "⏸️  Stopping non-critical services..."
~/manage-services.sh uptime-stop 2>/dev/null || true
~/manage-services.sh grafana-stop 2>/dev/null || true
sleep 3

echo "💾 Creating compressed eMMC image..."
echo "⏱️  This will take 20-45 minutes..."
echo ""

# Create the backup with progress
sudo dd if=/dev/mmcblk0 bs=4M status=progress | pv | gzip -c > ~/backups/${BACKUP_NAME}.img.gz

# Calculate checksums
echo ""
echo "🔐 Calculating checksums..."
cd ~/backups
sha256sum ${BACKUP_NAME}.img.gz > ${BACKUP_NAME}.img.gz.sha256

# Create restore instructions
cat > ~/backups/${BACKUP_NAME}_RESTORE_README.txt << EOL
=== reTerminal eMMC Restore Instructions ===

⚠️  CRITICAL: This backup is from eMMC, not SD card!

This backup can only be restored to:
- Another reTerminal with identical eMMC
- Using Raspberry Pi Compute Module tools

RESTORE METHODS:

Method 1: Using rpiboot (Recommended)
1. Install rpiboot on your computer
2. Put reTerminal in bootloader mode
3. Flash: gunzip -c ${BACKUP_NAME}.img.gz | sudo dd of=/dev/[device] bs=4M status=progress

Method 2: Network restore (Advanced)
1. Boot reTerminal with fresh OS
2. Transfer backup file
3. Restore with dd command

⚠️  WARNING: Restore will erase all data on target device!

For easier recovery, use application backups instead:
~/backup-manager.sh app
EOL

# Restart services
echo ""
echo "🔄 Restarting services..."
~/manage-services.sh uptime-start 2>/dev/null || true  
~/manage-services.sh grafana-start 2>/dev/null || true

echo ""
echo "✅ eMMC backup complete!"
echo "📁 Location: ~/backups/${BACKUP_NAME}.img.gz"
echo "🔐 Checksum: ~/backups/${BACKUP_NAME}.img.gz.sha256"
echo "📖 Instructions: ~/backups/${BACKUP_NAME}_RESTORE_README.txt"
echo "📏 Size: $(ls -lh ~/backups/${BACKUP_NAME}.img.gz | awk '{print $5}')"
echo ""
echo "⚠️  REMEMBER: This is eMMC backup, needs special restore process!"
echo "💡 For easier backups, use: ~/backup-manager.sh app"
echo ""
