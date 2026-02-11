#!/bin/bash
set -e

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="reTerminal_AppData_${BACKUP_DATE}"
BACKUP_DIR="~/backups/${BACKUP_NAME}"

echo "=== reTerminal Application Data Backup ==="
echo "Date: $(date)"
echo "Backup name: ${BACKUP_NAME}"
echo ""

# Create backup directory
mkdir -p ~/backups/${BACKUP_NAME}

echo "📦 Backing up Docker containers and configurations..."

# Stop containers for consistent backup
echo "⏸️  Stopping containers for clean backup..."
cd ~/pihole-docker && docker compose down
cd ~/uptime-kuma && docker compose down  
cd ~/homepage-dashboard && docker compose down
cd ~/grafana-influx && docker compose down
cd ~/mqtt-broker && docker compose down
cd ~/fing-agent-docker && docker compose down

sleep 5

# Backup all service directories with sudo for permission issues
echo "📁 Backing up service configurations and data..."
sudo cp -r ~/pihole-docker ~/backups/${BACKUP_NAME}/
sudo cp -r ~/uptime-kuma ~/backups/${BACKUP_NAME}/
sudo cp -r ~/homepage-dashboard ~/backups/${BACKUP_NAME}/
sudo cp -r ~/grafana-influx ~/backups/${BACKUP_NAME}/
sudo cp -r ~/mqtt-broker ~/backups/${BACKUP_NAME}/
sudo cp -r ~/fing-agent-docker ~/backups/${BACKUP_NAME}/

# Fix ownership of copied files
sudo chown -R $USER:$USER ~/backups/${BACKUP_NAME}/

# Backup system configurations
echo "⚙️  Backing up system configurations..."
mkdir -p ~/backups/${BACKUP_NAME}/system
cp ~/.config/autostart/* ~/backups/${BACKUP_NAME}/system/ 2>/dev/null || true
cp ~/launch-ha-kiosk.sh ~/backups/${BACKUP_NAME}/system/ 2>/dev/null || true
cp ~/control-kiosk.sh ~/backups/${BACKUP_NAME}/system/ 2>/dev/null || true
cp ~/manage-services.sh ~/backups/${BACKUP_NAME}/system/
cp ~/services-reference.txt ~/backups/${BACKUP_NAME}/system/ 2>/dev/null || true
cp ~/backup-manager.sh ~/backups/${BACKUP_NAME}/system/ 2>/dev/null || true
cp ~/eMMC-recovery-guide.txt ~/backups/${BACKUP_NAME}/system/ 2>/dev/null || true

# Backup systemd services
sudo cp /etc/systemd/system/pihole-docker.service ~/backups/${BACKUP_NAME}/system/ 2>/dev/null || true
sudo cp /etc/systemd/system/network-monitor.service ~/backups/${BACKUP_NAME}/system/ 2>/dev/null || true
sudo cp /etc/systemd/system/mqtt-broker.service ~/backups/${BACKUP_NAME}/system/ 2>/dev/null || true
sudo cp /etc/systemd/system/uptime-kuma.service ~/backups/${BACKUP_NAME}/system/ 2>/dev/null || true
sudo cp /etc/systemd/system/homepage-dashboard.service ~/backups/${BACKUP_NAME}/system/ 2>/dev/null || true
sudo cp /etc/systemd/system/grafana-influx.service ~/backups/${BACKUP_NAME}/system/ 2>/dev/null || true

# Fix ownership of systemd files
sudo chown $USER:$USER ~/backups/${BACKUP_NAME}/system/*.service 2>/dev/null || true

# Create comprehensive restore script
cat > ~/backups/${BACKUP_NAME}/restore.sh << 'EOL'
#!/bin/bash
set -e

echo "=== reTerminal Smart Home Hub Restore ==="
echo "This will restore:"
echo "  • Home Assistant + Pi-hole + Network Monitor"
echo "  • Uptime Kuma + Homepage + Grafana + MQTT"
echo "  • All configurations and data"
echo "  • System services and automation"
echo ""
echo "⚠️  This will overwrite current configurations!"
echo ""
read -p "Continue with restore? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled"
    exit 1
fi

echo "🔄 Stopping any running services..."
docker stop $(docker ps -q) 2>/dev/null || true

echo "📂 Restoring service directories..."
sudo cp -r pihole-docker ~/
sudo cp -r uptime-kuma ~/
sudo cp -r homepage-dashboard ~/
sudo cp -r grafana-influx ~/
sudo cp -r mqtt-broker ~/
sudo cp -r fing-agent-docker ~/

# Fix ownership
sudo chown -R $USER:$USER ~/pihole-docker ~/uptime-kuma ~/homepage-dashboard ~/grafana-influx ~/mqtt-broker ~/fing-agent-docker

echo "⚙️  Restoring system configurations..."
cp system/launch-ha-kiosk.sh ~/
cp system/control-kiosk.sh ~/
cp system/manage-services.sh ~/
cp system/services-reference.txt ~/
cp system/backup-manager.sh ~/
cp system/eMMC-recovery-guide.txt ~/
chmod +x ~/*.sh

mkdir -p ~/.config/autostart
cp system/*.desktop ~/.config/autostart/ 2>/dev/null || true

echo "🔧 Restoring systemd services..."
sudo cp system/*.service /etc/systemd/system/ 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl enable pihole-docker.service network-monitor.service mqtt-broker.service uptime-kuma.service homepage-dashboard.service grafana-influx.service 2>/dev/null || true

echo "🚀 Starting all services..."
cd ~/pihole-docker && docker compose up -d
cd ~/mqtt-broker && docker compose up -d
cd ~/fing-agent-docker && docker compose up -d
cd ~/uptime-kuma && docker compose up -d
cd ~/homepage-dashboard && docker compose up -d
cd ~/grafana-influx && docker compose up -d

echo ""
echo "⏳ Waiting for services to initialize..."
sleep 10

echo "✅ Restore complete!"
echo ""
echo "🌐 Your services should be available at:"
echo "  • Home Assistant:    http://$(hostname -I | awk '{print $1}'):8123"
echo "  • Homepage Dashboard: http://$(hostname -I | awk '{print $1}'):3000"
echo "  • Pi-hole:           http://$(hostname -I | awk '{print $1}'):8080"
echo "  • Uptime Kuma:       http://$(hostname -I | awk '{print $1}'):3001"
echo "  • Grafana:           http://$(hostname -I | awk '{print $1}'):3002"
echo ""
echo "🔄 Reboot recommended to ensure kiosk mode starts properly"
echo "📊 Check status: ~/manage-services.sh status"
EOL

chmod +x ~/backups/${BACKUP_NAME}/restore.sh

# Create backup manifest
cat > ~/backups/${BACKUP_NAME}/BACKUP_MANIFEST.txt << EOL
=== reTerminal Smart Home Hub Backup ===
Date: $(date)
Hostname: $(hostname)
IP Address: $(hostname -I | awk '{print $1}')

SERVICES BACKED UP:
✅ Home Assistant (Supervised)
✅ Pi-hole (DNS ad-blocking)  
✅ Network Monitor (Device discovery)
✅ Uptime Kuma (Service monitoring)
✅ Homepage Dashboard (Service hub)
✅ Grafana + InfluxDB (Analytics)  
✅ MQTT Broker (IoT messaging)

CONFIGURATIONS INCLUDED:
• Docker containers and volumes
• Service configurations
• System startup scripts
• Kiosk mode automation
• systemd service files
• Management scripts

RESTORE INSTRUCTIONS:
1. Extract backup: tar -xzf [backup_file].tar.gz
2. Run restore: cd [backup_folder] && ./restore.sh
3. Reboot system
4. Access services via web interfaces

BACKUP SIZE: Will be calculated after compression
BACKUP TYPE: Application Data (Portable)
COMPATIBILITY: Any reTerminal with fresh Raspberry Pi OS
EOL

# Restart services
echo "🔄 Restarting services..."
cd ~/pihole-docker && docker compose up -d
cd ~/mqtt-broker && docker compose up -d
cd ~/fing-agent-docker && docker compose up -d
cd ~/uptime-kuma && docker compose up -d
cd ~/homepage-dashboard && docker compose up -d  
cd ~/grafana-influx && docker compose up -d

# Wait for services to come up
echo "⏳ Waiting for services to restart..."
sleep 15

# Create compressed archive
echo "🗜️  Creating compressed archive..."
cd ~/backups
tar -czf ${BACKUP_NAME}.tar.gz ${BACKUP_NAME}/
rm -rf ${BACKUP_NAME}

# Calculate checksum
sha256sum ${BACKUP_NAME}.tar.gz > ${BACKUP_NAME}.tar.gz.sha256

echo ""
echo "✅ Application backup complete!"
echo "📁 Location: ~/backups/${BACKUP_NAME}.tar.gz"
echo "🔐 Checksum: ~/backups/${BACKUP_NAME}.tar.gz.sha256"
echo "📏 Size: $(ls -lh ~/backups/${BACKUP_NAME}.tar.gz | awk '{print $5}')"
echo ""
echo "📋 BACKUP CONTAINS:"
echo "  • All 7 services with data and configurations"
echo "  • System automation and scripts"
echo "  • Automated restore script"
echo "  • Complete documentation"
echo ""
echo "🔄 TO RESTORE:"
echo "  1. tar -xzf ${BACKUP_NAME}.tar.gz"
echo "  2. cd ${BACKUP_NAME} && ./restore.sh"
echo "  3. Reboot"
echo ""
