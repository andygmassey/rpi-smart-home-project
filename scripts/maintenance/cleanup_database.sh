#!/bin/bash
# One-time database cleanup script

echo "=== Pi-hole Database Cleanup ==="
echo "Current database size:"
docker exec pihole du -h /etc/pihole/pihole-FTL.db

echo ""
echo "Stopping Pi-hole to vacuum database..."
docker stop pihole

echo "Backing up database..."
cp /home/massey/pihole-docker/etc-pihole/pihole-FTL.db /home/massey/pihole-docker/etc-pihole/pihole-FTL.db.backup

echo "Vacuuming database..."
sqlite3 /home/massey/pihole-docker/etc-pihole/pihole-FTL.db "VACUUM;"

echo "Database size after vacuum:"
du -h /home/massey/pihole-docker/etc-pihole/pihole-FTL.db

echo "Starting Pi-hole..."
docker start pihole

echo ""
echo "=== Cleanup Complete ==="
echo "Old data will be automatically removed after 7 days per new config"
