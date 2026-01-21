#!/bin/bash
set -e

# reTerminal Smart Home - Deployment Script
# This script deploys the repo configuration to the live system
# IMPORTANT: Always creates a backup before making changes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR=~/backups
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=============================================="
echo "  reTerminal Smart Home - Deployment Script"
echo "=============================================="
echo ""

# Check if running on the reTerminal
if [[ ! -f /proc/device-tree/model ]] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo -e "${YELLOW}Warning: This doesn't appear to be a Raspberry Pi.${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 1
    fi
fi

# Check for .env file
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
    echo -e "${YELLOW}Warning: No .env file found.${NC}"
    echo "Creating from .env.example - you should edit this with your actual passwords!"
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
fi

# Source environment variables
source "$SCRIPT_DIR/.env"

echo "Deployment options:"
echo "  1) Full deployment (docker configs + scripts + systemd)"
echo "  2) Docker configs only"
echo "  3) Scripts only"
echo "  4) Systemd services only"
echo "  5) Dry run (show what would be done)"
echo "  6) Cancel"
echo ""
read -p "Select option [1-6]: " DEPLOY_OPTION

case $DEPLOY_OPTION in
    6)
        echo "Deployment cancelled."
        exit 0
        ;;
    5)
        DRY_RUN=true
        echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"
        ;;
    *)
        DRY_RUN=false
        ;;
esac

# Create backup before deployment
echo ""
echo "Step 1: Creating pre-deployment backup..."
mkdir -p "$BACKUP_DIR"

if [[ "$DRY_RUN" == "false" ]]; then
    BACKUP_NAME="pre-deploy-${TIMESTAMP}"
    mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

    # Backup current docker directories
    for service in grafana-influx pihole-docker homepage-dashboard mqtt-broker uptime-kuma; do
        if [[ -d ~/$service ]]; then
            echo "  Backing up ~/$service..."
            sudo cp -r ~/$service "$BACKUP_DIR/$BACKUP_NAME/" 2>/dev/null || true
        fi
    done

    # Backup scripts
    mkdir -p "$BACKUP_DIR/$BACKUP_NAME/scripts"
    cp ~/*.sh "$BACKUP_DIR/$BACKUP_NAME/scripts/" 2>/dev/null || true
    cp ~/*.py "$BACKUP_DIR/$BACKUP_NAME/scripts/" 2>/dev/null || true

    # Backup crontab
    crontab -l > "$BACKUP_DIR/$BACKUP_NAME/crontab.txt" 2>/dev/null || true

    # Fix ownership
    sudo chown -R $(whoami):$(whoami) "$BACKUP_DIR/$BACKUP_NAME"

    echo -e "${GREEN}  Backup created: $BACKUP_DIR/$BACKUP_NAME${NC}"
else
    echo "  [DRY RUN] Would create backup at $BACKUP_DIR/pre-deploy-${TIMESTAMP}"
fi

# Deploy Docker configurations
if [[ "$DEPLOY_OPTION" == "1" || "$DEPLOY_OPTION" == "2" || "$DEPLOY_OPTION" == "5" ]]; then
    echo ""
    echo "Step 2: Deploying Docker configurations..."

    # Map repo directories to live directories
    declare -A DOCKER_MAP=(
        ["docker/grafana-influx"]="grafana-influx"
        ["docker/pihole"]="pihole-docker"
        ["docker/homepage"]="homepage-dashboard"
        ["docker/mqtt-broker"]="mqtt-broker"
        ["docker/uptime-kuma"]="uptime-kuma"
    )

    for repo_path in "${!DOCKER_MAP[@]}"; do
        live_path="${DOCKER_MAP[$repo_path]}"
        if [[ -d "$SCRIPT_DIR/$repo_path" ]]; then
            if [[ "$DRY_RUN" == "false" ]]; then
                echo "  Deploying $repo_path -> ~/$live_path..."
                # Only copy docker-compose.yml and config directories, preserve data
                cp "$SCRIPT_DIR/$repo_path/docker-compose.yml" ~/$live_path/ 2>/dev/null || mkdir -p ~/$live_path && cp "$SCRIPT_DIR/$repo_path/docker-compose.yml" ~/$live_path/
                if [[ -d "$SCRIPT_DIR/$repo_path/config" ]]; then
                    cp -r "$SCRIPT_DIR/$repo_path/config" ~/$live_path/
                fi
            else
                echo "  [DRY RUN] Would deploy $repo_path -> ~/$live_path"
            fi
        fi
    done

    # Copy .env file to each service directory
    if [[ "$DRY_RUN" == "false" ]]; then
        for live_path in grafana-influx pihole-docker homepage-dashboard mqtt-broker uptime-kuma; do
            if [[ -d ~/$live_path ]]; then
                cp "$SCRIPT_DIR/.env" ~/$live_path/.env 2>/dev/null || true
            fi
        done
    fi
fi

# Deploy scripts
if [[ "$DEPLOY_OPTION" == "1" || "$DEPLOY_OPTION" == "3" || "$DEPLOY_OPTION" == "5" ]]; then
    echo ""
    echo "Step 3: Deploying scripts..."

    SCRIPT_DIRS=("scripts/backup" "scripts/system" "scripts/monitoring" "scripts/maintenance" "scripts/hardware")

    for script_dir in "${SCRIPT_DIRS[@]}"; do
        if [[ -d "$SCRIPT_DIR/$script_dir" ]]; then
            for script in "$SCRIPT_DIR/$script_dir"/*.{sh,py} 2>/dev/null; do
                if [[ -f "$script" ]]; then
                    script_name=$(basename "$script")
                    if [[ "$DRY_RUN" == "false" ]]; then
                        echo "  Deploying $script_name..."
                        cp "$script" ~/
                        chmod +x ~/"$script_name"
                    else
                        echo "  [DRY RUN] Would deploy $script_name to ~/"
                    fi
                fi
            done
        fi
    done
fi

# Deploy systemd services
if [[ "$DEPLOY_OPTION" == "1" || "$DEPLOY_OPTION" == "4" || "$DEPLOY_OPTION" == "5" ]]; then
    echo ""
    echo "Step 4: Deploying systemd services..."

    if [[ -d "$SCRIPT_DIR/system/systemd" ]]; then
        for service in "$SCRIPT_DIR/system/systemd"/*.service; do
            if [[ -f "$service" ]]; then
                service_name=$(basename "$service")
                if [[ "$DRY_RUN" == "false" ]]; then
                    echo "  Installing $service_name..."
                    sudo cp "$service" /etc/systemd/system/
                else
                    echo "  [DRY RUN] Would install $service_name to /etc/systemd/system/"
                fi
            fi
        done

        if [[ "$DRY_RUN" == "false" ]]; then
            echo "  Reloading systemd daemon..."
            sudo systemctl daemon-reload
        fi
    fi
fi

# Summary
echo ""
echo "=============================================="
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}DRY RUN COMPLETE - No changes were made${NC}"
else
    echo -e "${GREEN}DEPLOYMENT COMPLETE${NC}"
    echo ""
    echo "Backup location: $BACKUP_DIR/$BACKUP_NAME"
    echo ""
    echo "To rollback, run:"
    echo "  ./rollback.sh $BACKUP_DIR/$BACKUP_NAME"
    echo ""
    echo "To restart services:"
    echo "  sudo reboot"
    echo "  # or restart individual services:"
    echo "  cd ~/grafana-influx && docker compose up -d"
fi
echo "=============================================="
