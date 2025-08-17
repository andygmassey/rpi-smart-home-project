#!/bin/bash

show_status() {
    echo "=== reTerminal Smart Home Hub Status ==="
    echo ""
    echo "🏠 HOME ASSISTANT:"
    if systemctl is-active --quiet hassio-supervisor; then
        echo "  Status: ✅ Running"
        echo "  Web UI: http://192.168.1.76:8123"
    else
        echo "  Status: ❌ Not running"
    fi
    
    echo ""
    echo "🛡️ PI-HOLE:"
    if docker ps --filter "name=pihole" --filter "status=running" -q | grep -q .; then
        echo "  Status: ✅ Running"
        echo "  Web UI: http://192.168.1.76:8080"
        echo "  DNS: 192.168.1.76:1053"
    else
        echo "  Status: ❌ Not running"
    fi
    
    echo ""
    echo "🔍 NETWORK MONITOR:"
    if docker ps --filter "name=network-monitor" --filter "status=running" -q | grep -q .; then
        echo "  Status: ✅ Running"
        echo "  Scan data: ~/fing-agent-docker/logs/network-scan.json"
        if [ -f ~/fing-agent-docker/logs/network-scan.json ]; then
            DEVICE_COUNT=$(jq '.devices | length' ~/fing-agent-docker/logs/network-scan.json 2>/dev/null || echo "0")
            LAST_SCAN=$(jq -r '.timestamp' ~/fing-agent-docker/logs/network-scan.json 2>/dev/null | cut -d'T' -f1 || echo "Unknown")
            echo "  Devices found: ${DEVICE_COUNT} (Last scan: ${LAST_SCAN})"
        fi
    else
        echo "  Status: ❌ Not running"
    fi
    
    echo ""
    echo "📊 UPTIME KUMA:"
    if docker ps --filter "name=uptime-kuma" --filter "status=running" -q | grep -q .; then
        echo "  Status: ✅ Running"
        echo "  Web UI: http://192.168.1.76:3001"
    else
        echo "  Status: ❌ Not running"
    fi
    
    echo ""
    echo "🏠 HOMEPAGE DASHBOARD:"
    if docker ps --filter "name=homepage" --filter "status=running" -q | grep -q .; then
        echo "  Status: ✅ Running"
        echo "  Web UI: http://192.168.1.76:3000"
    else
        echo "  Status: ❌ Not running"
    fi
    
    echo ""
    echo "📊 GRAFANA & INFLUXDB:"
    if docker ps --filter "name=grafana" --filter "status=running" -q | grep -q .; then
        echo "  Status: ✅ Running"
        echo "  Grafana: http://192.168.1.76:3002 (admin/admin123)"
        echo "  InfluxDB: http://192.168.1.76:8086"
    else
        echo "  Status: ❌ Not running"
    fi
    
    echo ""
    echo "📡 MQTT BROKER:"
    if docker ps --filter "name=mosquitto" --filter "status=running" -q | grep -q .; then
        echo "  Status: ✅ Running"
        echo "  MQTT: 192.168.1.76:1883"
        echo "  WebSocket: 192.168.1.76:9001"
    else
        echo "  Status: ❌ Not running"
    fi
    
    echo ""
    echo "🖥️ KIOSK MODE:"
    if pgrep -f "chromium-browser.*kiosk" > /dev/null; then
        echo "  Status: ✅ Running"
    else
        echo "  Status: ❌ Not running"
    fi
}

case "$1" in
    status)
        show_status
        ;;
    # Home Assistant and original services
    pihole-start|pihole-stop|pihole-restart)
        ACTION=${1#pihole-}
        echo "${ACTION^}ing Pi-hole..."
        cd ~/pihole-docker && docker compose $ACTION -d 2>/dev/null || docker compose $ACTION
        ;;
    network-start|network-stop|network-restart)
        ACTION=${1#network-}
        echo "${ACTION^}ing Network Monitor..."
        cd ~/fing-agent-docker && docker compose $ACTION -d 2>/dev/null || docker compose $ACTION
        ;;
    network-scan)
        echo "Latest network scan results:"
        if [ -f ~/fing-agent-docker/logs/network-scan.json ]; then
            jq -r '.devices[] | "\(.ip)\t\(.mac)\t\(.vendor)"' ~/fing-agent-docker/logs/network-scan.json | column -t
        else
            echo "No scan data available yet"
        fi
        ;;
    # New services
    uptime-start|uptime-stop|uptime-restart)
        ACTION=${1#uptime-}
        echo "${ACTION^}ing Uptime Kuma..."
        cd ~/uptime-kuma && docker compose $ACTION -d 2>/dev/null || docker compose $ACTION
        ;;
    homepage-start|homepage-stop|homepage-restart)
        ACTION=${1#homepage-}
        echo "${ACTION^}ing Homepage Dashboard..."
        cd ~/homepage-dashboard && docker compose $ACTION -d 2>/dev/null || docker compose $ACTION
        ;;
    grafana-start|grafana-stop|grafana-restart)
        ACTION=${1#grafana-}
        echo "${ACTION^}ing Grafana & InfluxDB..."
        cd ~/grafana-influx && docker compose $ACTION -d 2>/dev/null || docker compose $ACTION
        ;;
    mqtt-start|mqtt-stop|mqtt-restart)
        ACTION=${1#mqtt-}
        echo "${ACTION^}ing MQTT Broker..."
        cd ~/mqtt-broker && docker compose $ACTION -d 2>/dev/null || docker compose $ACTION
        ;;
    # Kiosk controls
    kiosk-start|kiosk-stop|kiosk-restart)
        ACTION=${1#kiosk-}
        echo "${ACTION^}ing kiosk mode..."
        ~/control-kiosk.sh $ACTION
        ;;
    # Log viewers
    logs-pihole)
        cd ~/pihole-docker && docker compose logs -f
        ;;
    logs-ha)
        docker logs homeassistant -f
        ;;
    logs-network)
        cd ~/fing-agent-docker && docker compose logs -f
        ;;
    logs-uptime)
        cd ~/uptime-kuma && docker compose logs -f
        ;;
    logs-homepage)
        cd ~/homepage-dashboard && docker compose logs -f
        ;;
    logs-grafana)
        cd ~/grafana-influx && docker compose logs -f
        ;;
    logs-mqtt)
        cd ~/mqtt-broker && docker compose logs -f
        ;;
    mqtt-test)
        echo "Testing MQTT broker..."
        mosquitto_pub -h localhost -t reTerminal/test -m "Test message from $(date)" &
        echo "Sent test message, listening for 3 seconds..."
        timeout 3 mosquitto_sub -h localhost -t reTerminal/test -C 1
        ;;
    *)
        echo "reTerminal Smart Home Hub Manager"
        echo "=================================="
        echo "Usage: $0 {COMMAND}"
        echo ""
        echo "Main Commands:"
        echo "  status                     Show all services status"
        echo ""
        echo "Service Controls:"
        echo "  {pihole|network|uptime|homepage|grafana|mqtt|kiosk}-{start|stop|restart}"
        echo ""
        echo "Special Commands:"
        echo "  network-scan              Show latest network scan"
        echo "  mqtt-test                 Test MQTT broker"
        echo ""
        echo "Log Viewing:"
        echo "  logs-{pihole|ha|network|uptime|homepage|grafana|mqtt}"
        echo ""
        echo "Quick status check:"
        echo "==================="
        show_status
        ;;
esac
