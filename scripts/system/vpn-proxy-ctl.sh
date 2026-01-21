#!/bin/bash
# VPN Proxy Control Script
# Usage: vpn-proxy-ctl.sh [start|stop|status|restart]

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

case "$1" in
    start)
        echo -e "${YELLOW}Starting VPN and proxy...${NC}"
        sudo systemctl start unlocator-vpn
        sleep 3
        sudo systemctl start vpn-proxy
        sudo /usr/local/bin/vpn-killswitch.sh enable
        echo -e "${GREEN}VPN proxy started${NC}"
        $0 status
        ;;
    stop)
        echo -e "${YELLOW}Stopping VPN and proxy...${NC}"
        sudo /usr/local/bin/vpn-killswitch.sh disable
        sudo systemctl stop vpn-proxy
        sudo systemctl stop unlocator-vpn
        echo -e "${RED}VPN proxy stopped${NC}"
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        echo ""
        echo "=== VPN Proxy Status ==="
        echo ""
        
        # VPN Status
        if systemctl is-active --quiet unlocator-vpn; then
            VPN_IP=$(ip addr show tun0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
            echo -e "VPN:        ${GREEN}CONNECTED${NC} ($VPN_IP)"
        else
            echo -e "VPN:        ${RED}DISCONNECTED${NC}"
        fi
        
        # Proxy Status
        if systemctl is-active --quiet vpn-proxy; then
            echo -e "Proxy:      ${GREEN}RUNNING${NC} (port 1080)"
        else
            echo -e "Proxy:      ${RED}STOPPED${NC}"
        fi
        
        # Kill Switch Status
        if iptables -L OUTPUT -n 2>/dev/null | grep -q "mark match 0x1"; then
            echo -e "Kill Switch:${GREEN}ENABLED${NC}"
        else
            echo -e "Kill Switch:${YELLOW}DISABLED${NC}"
        fi
        
        # External IP (through VPN)
        if systemctl is-active --quiet vpn-proxy; then
            echo ""
            echo -n "External IP: "
            curl -s --socks5 127.0.0.1:1080 --max-time 5 https://api.ipify.org 2>/dev/null || echo "(check failed)"
            echo ""
        fi
        ;;
    test)
        echo "Testing proxy connection..."
        curl -s --socks5 127.0.0.1:1080 --max-time 10 https://api.ipify.org && echo " (VPN IP)"
        ;;
    *)
        echo "VPN Proxy Control"
        echo "Usage: $0 {start|stop|restart|status|test}"
        echo ""
        echo "  start   - Start VPN and proxy with kill switch"
        echo "  stop    - Stop VPN and proxy"
        echo "  restart - Restart VPN and proxy"
        echo "  status  - Show current status"
        echo "  test    - Test proxy connection"
        exit 1
        ;;
esac
