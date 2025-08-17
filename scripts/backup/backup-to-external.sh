#!/bin/bash
set -e

MOUNT_POINT="/mnt/backup"
BACKUP_TYPE="$1"

if [ -z "$BACKUP_TYPE" ]; then
    echo "Usage: $0 {app|full}"
    echo "This script helps copy backups to external storage"
    exit 1
fi

echo "=== External Backup Helper ==="
echo "Available USB devices:"
lsblk | grep -E "sd[a-z]"

echo ""
echo "To mount USB drive:"
echo "1. sudo mkdir -p $MOUNT_POINT"
echo "2. sudo mount /dev/sdX1 $MOUNT_POINT  # Replace sdX1 with your USB device"
echo "3. Run this script again"
echo ""

if mountpoint -q $MOUNT_POINT; then
    echo "✅ External storage mounted at $MOUNT_POINT"
    
    if [ "$BACKUP_TYPE" = "app" ]; then
        echo "Creating app backup and copying to external storage..."
        ~/backup-manager.sh app
        cp ~/backups/*AppData*.tar.gz* $MOUNT_POINT/
        echo "✅ App backup copied to external storage"
    elif [ "$BACKUP_TYPE" = "full" ]; then
        echo "Creating full backup and copying to external storage..."
        ~/backup-manager.sh full  
        cp ~/backups/*SmartHome*.img.gz* $MOUNT_POINT/
        echo "✅ Full backup copied to external storage"
    fi
    
    echo "📁 External storage contents:"
    ls -lh $MOUNT_POINT/
    
    echo ""
    echo "To safely unmount: sudo umount $MOUNT_POINT"
else
    echo "❌ No external storage mounted at $MOUNT_POINT"
fi
