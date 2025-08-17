#!/bin/bash

case "$1" in
    list)
        echo "=== Available Backups ==="
        if [ -d ~/backups ]; then
            echo "Application Backups:"
            ls -lh ~/backups/ | grep "AppData.*tar.gz" | awk '{print "  " $9 "\t" $5 "\t" $6 " " $7 " " $8}' || echo "  None found"
            echo ""
            echo "System Backups (eMMC):"
            ls -lh ~/backups/ | grep "eMMC.*img.gz" | awk '{print "  " $9 "\t" $5 "\t" $6 " " $7 " " $8}' || echo "  None found"
        else
            echo "No backups directory found"
        fi
        ;;
    app)
        echo "🔄 Starting APPLICATION data backup (RECOMMENDED)..."
        ~/create-app-backup.sh
        ;;
    system)
        echo "🔄 Starting eMMC SYSTEM backup (Advanced)..."
        echo "⚠️  Note: eMMC backups are complex to restore!"
        ~/create-system-backup.sh
        ;;
    space)
        echo "=== Storage Information ==="
        echo "eMMC Storage:"
        lsblk /dev/mmcblk0 -o NAME,SIZE,TYPE,MOUNTPOINT
        echo ""
        echo "Disk Usage:"
        df -h / | tail -1
        echo ""
        if [ -d ~/backups ]; then
            echo "Backup directory size:"
            du -sh ~/backups 2>/dev/null || echo "No backups directory"
        fi
        ;;
    info)
        echo "=== reTerminal eMMC Backup Guide ==="
        echo ""
        echo "🏠 HARDWARE: reTerminal uses 32GB eMMC (not SD card)"
        echo "📱 DEVICE: $(cat /proc/cpuinfo | grep Model | cut -d: -f2 | xargs)"
        echo "💾 STORAGE: $(lsblk /dev/mmcblk0 -o SIZE --noheadings | tr -d ' ') eMMC"
        echo ""
        echo "📋 BACKUP OPTIONS:"
        echo ""
        echo "1. 📦 APPLICATION BACKUP (Recommended)"
        echo "   • Backs up all your services and configurations"
        echo "   • Fast (2-5 minutes, ~2GB)"
        echo "   • Easy to restore on any reTerminal"
        echo "   • Command: ~/backup-manager.sh app"
        echo ""
        echo "2. 💾 SYSTEM BACKUP (Advanced)" 
        echo "   • Complete eMMC image"
        echo "   • Slow (20-45 minutes, ~10GB)"
        echo "   • Complex restore process"
        echo "   • Requires identical hardware"
        echo "   • Command: ~/backup-manager.sh system"
        echo ""
        echo "🎯 RECOMMENDATION:"
        echo "   Use APPLICATION backup for regular backups"
        echo "   Use SYSTEM backup only for disaster recovery"
        echo ""
        ;;
    *)
        echo "reTerminal eMMC Backup Manager"
        echo "=============================="
        echo "Usage: $0 {app|system|list|space|info}"
        echo ""
        echo "Commands:"
        echo "  app      Create application backup (RECOMMENDED - fast & easy)"
        echo "  system   Create full eMMC system backup (advanced users only)"
        echo "  list     List existing backups"
        echo "  space    Check storage information"
        echo "  info     Show detailed backup guide"
        echo ""
        echo "💡 For most users: ~/backup-manager.sh app"
        echo ""
        echo "Current storage:"
        df -h / | tail -1
        ;;
esac
