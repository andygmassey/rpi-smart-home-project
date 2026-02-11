#!/bin/bash

case "$1" in
    start)
        echo "🚀 Starting VNC remote desktop..."
        x11vnc -display :0 -rfbauth ~/.vnc/passwd -shared -forever -noxdamage -repeat -rfbport 5900 &
        sleep 2
        echo "✅ VNC server started on port 5900"
        echo "🌐 Access via web browser: http://192.168.1.100:6080/vnc.html"
        echo "📱 Or VNC client: 192.168.1.100:5900"
        ;;
    stop)
        echo "⏹️  Stopping VNC services..."
        pkill x11vnc && echo "VNC server stopped" || echo "VNC server wasn't running"
        pkill websockify && echo "Web VNC stopped" || echo "Web VNC wasn't running"
        ;;
    status)
        echo "=== VNC Remote Desktop Status ==="
        if pgrep x11vnc > /dev/null; then
            echo "VNC Server: ✅ Running (port 5900)"
        else
            echo "VNC Server: ❌ Not running"
        fi
        
        if pgrep websockify > /dev/null; then
            echo "Web VNC: ✅ Running (port 6080)"
        else
            echo "Web VNC: ❌ Not running"
        fi
        
        if pgrep x11vnc > /dev/null; then
            echo ""
            echo "🌐 Access via browser: http://192.168.1.100:6080/vnc.html"
            echo "📱 VNC client: 192.168.1.100:5900"
        fi
        ;;
    restart)
        echo "🔄 Restarting VNC services..."
        $0 stop
        sleep 2
        $0 start
        ;;
    *)
        echo "VNC Remote Desktop Control"
        echo "========================="
        echo "Usage: $0 {start|stop|status|restart}"
        echo ""
        echo "Commands:"
        echo "  start    Start VNC remote desktop"
        echo "  stop     Stop VNC services"  
        echo "  status   Show VNC status"
        echo "  restart  Restart VNC services"
        echo ""
        $0 status
        ;;
esac
