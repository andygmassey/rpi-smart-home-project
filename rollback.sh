#!/bin/bash
set -e

# reTerminal Smart Home - Rollback Script
# Restores system to a previous backup state

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=============================================="
echo "  reTerminal Smart Home - Rollback Script"
echo "=============================================="
echo ""

# Check for backup path argument
if [[ -z "$1" ]]; then
    echo "Usage: $0 <backup_path>"
    echo ""
    echo "Available backups:"
    ls -la ~/backups/ 2>/dev/null | grep -E "^d.*pre-" | awk '{print "  " $NF}'
    ls -la ~/backups/*.tar.gz 2>/dev/null | awk '{print "  " $NF}'
    exit 1
fi

BACKUP_PATH="$1"

# Handle tar.gz archives
if [[ "$BACKUP_PATH" == *.tar.gz ]]; then
    echo "Extracting backup archive..."
    EXTRACT_DIR=$(dirname "$BACKUP_PATH")
    tar -xzf "$BACKUP_PATH" -C "$EXTRACT_DIR"
    BACKUP_PATH="${BACKUP_PATH%.tar.gz}"
fi

# Verify backup exists
if [[ ! -d "$BACKUP_PATH" ]]; then
    echo -e "${RED}Error: Backup directory not found: $BACKUP_PATH${NC}"
    exit 1
fi

echo "Backup path: $BACKUP_PATH"
echo ""

# Show what will be restored
echo "This will restore:"
[[ -d "$BACKUP_PATH/grafana-influx" ]] && echo "  - grafana-influx"
[[ -d "$BACKUP_PATH/pihole-docker" ]] && echo "  - pihole-docker"
[[ -d "$BACKUP_PATH/homepage-dashboard" ]] && echo "  - homepage-dashboard"
[[ -d "$BACKUP_PATH/mqtt-broker" ]] && echo "  - mqtt-broker"
[[ -d "$BACKUP_PATH/uptime-kuma" ]] && echo "  - uptime-kuma"
[[ -d "$BACKUP_PATH/scripts" ]] && echo "  - scripts"
[[ -d "$BACKUP_PATH/systemd" ]] && echo "  - systemd services"
[[ -f "$BACKUP_PATH/crontab.txt" ]] && echo "  - crontab"

echo ""
echo -e "${YELLOW}WARNING: This will overwrite current configurations!${NC}"
read -p "Continue with rollback? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Rollback cancelled."
    exit 0
fi

echo ""
echo "Step 1: Stopping Docker services..."
docker stop $(docker ps -q --filter "name=grafana" --filter "name=influxdb" --filter "name=homepage" --filter "name=mosquitto" --filter "name=uptime-kuma" --filter "name=pihole") 2>/dev/null || true

echo ""
echo "Step 2: Restoring Docker configurations..."
for service in grafana-influx pihole-docker homepage-dashboard mqtt-broker uptime-kuma; do
    if [[ -d "$BACKUP_PATH/$service" ]]; then
        echo "  Restoring $service..."
        sudo rm -rf ~/$service
        sudo cp -r "$BACKUP_PATH/$service" ~/
        sudo chown -R $(whoami):$(whoami) ~/$service
    fi
done

echo ""
echo "Step 3: Restoring scripts..."
if [[ -d "$BACKUP_PATH/scripts" ]]; then
    for script in "$BACKUP_PATH/scripts"/*.{sh,py} 2>/dev/null; do
        if [[ -f "$script" ]]; then
            script_name=$(basename "$script")
            echo "  Restoring $script_name..."
            cp "$script" ~/
            chmod +x ~/"$script_name"
        fi
    done
fi

echo ""
echo "Step 4: Restoring systemd services..."
if [[ -d "$BACKUP_PATH/systemd" ]]; then
    for service in "$BACKUP_PATH/systemd"/*.service 2>/dev/null; do
        if [[ -f "$service" ]]; then
            service_name=$(basename "$service")
            echo "  Restoring $service_name..."
            sudo cp "$service" /etc/systemd/system/
        fi
    done
    sudo systemctl daemon-reload
fi

echo ""
echo "Step 5: Restoring crontab..."
if [[ -f "$BACKUP_PATH/crontab.txt" ]]; then
    crontab "$BACKUP_PATH/crontab.txt"
    echo "  Crontab restored."
fi

echo ""
echo "Step 6: Restarting services..."
for service in grafana-influx mqtt-broker homepage-dashboard uptime-kuma; do
    if [[ -d ~/$service ]]; then
        echo "  Starting $service..."
        cd ~/$service && docker compose up -d 2>/dev/null || true
    fi
done

echo ""
echo "=============================================="
echo -e "${GREEN}ROLLBACK COMPLETE${NC}"
echo ""
echo "Services have been restarted. Check status with:"
echo "  ~/manage-services.sh status"
echo ""
echo "If you experience issues, consider rebooting:"
echo "  sudo reboot"
echo "=============================================="
