#!/bin/bash
# Borg Backup Script for reTerminal
# Runs every 2 weeks via cron
# ionice -c 3 (idle class) prevents backup I/O from starving VPN keepalives

export BORG_RELOCATED_REPO_ACCESS_IS_OK=yes
REPO=/mnt/borg/reterminal
ARCHIVE="reTerminal-$(date +%Y-%m-%d_%H%M)"

echo "[$(date)] Starting Borg backup (ionice idle class)..."

ionice -c 3 borg create -v --stats --one-file-system \
    --exclude-caches \
    --exclude '/tmp/*' \
    --exclude '/var/tmp/*' \
    --exclude '/var/cache/*' \
    --exclude '/var/log/*.log' \
    --exclude '/home/*/.cache' \
    --exclude '*.pyc' \
    --exclude '__pycache__' \
    "$REPO::$ARCHIVE" /

ionice -c 3 borg prune -v "$REPO" --keep-within 42d --keep-weekly 4 --prefix reTerminal-

echo "[$(date)] Backup complete"
