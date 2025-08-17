#!/bin/bash

case "$1" in
    start)
        echo "Starting Home Assistant Kiosk..."
        nohup ~/launch-ha-kiosk.sh > /dev/null 2>&1 &
        echo "Kiosk started in background"
        ;;
    stop)
        echo "Stopping Chromium kiosk..."
        pkill -f "chromium-browser.*kiosk"
        echo "Kiosk stopped"
        ;;
    status)
        if pgrep -f "chromium-browser.*kiosk" > /dev/null; then
            echo "Kiosk is running"
        else
            echo "Kiosk is not running"
        fi
        ;;
    restart)
        echo "Restarting kiosk..."
        $0 stop
        sleep 3
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
