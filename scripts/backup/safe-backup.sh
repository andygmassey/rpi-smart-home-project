#!/bin/bash
# Safe backup that stops services first

echo "🛑 SAFE BACKUP MODE"
echo "This will temporarily stop services to free memory"
echo ""
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Backup cancelled"
    exit 0
fi

echo ""
echo "1/4 Stopping non-essential services..."
docker stop homepage grafana uptime-kuma

echo "2/4 Waiting for memory to clear..."
sleep 10

echo "3/4 Starting backup (will take 20-40 minutes)..."
sudo /home/massey/create-goldmaster-backup-compressed.sh

echo "4/4 Restarting services..."
cd ~/homepage-dashboard && docker-compose up -d
cd ~/grafana-influx && docker-compose up -d  
cd ~/uptime-kuma && docker-compose up -d

echo ""
echo "✅ Backup complete! Services restored."
