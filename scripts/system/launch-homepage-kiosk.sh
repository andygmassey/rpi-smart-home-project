#!/bin/bash
# Homepage Dashboard Kiosk Mode

# Wait for Homepage to be ready
echo "Waiting for Homepage Dashboard to start..."
until curl -s http://localhost:3000 > /dev/null 2>&1; do
    echo "Homepage not ready yet, waiting 10 seconds..."
    sleep 10
done

echo "Homepage is ready! Launching kiosk mode in 5 seconds..."
sleep 5

# Disable screensaver and screen blanking
xset s off
xset -dpms  
xset s noblank

# Kill any existing Chromium instances
pkill -f chromium-browser

# Launch Chromium in kiosk mode pointing to Homepage
chromium-browser \
    --kiosk \
    --no-sandbox \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-restore-session-state \
    --disable-features=TranslateUI \
    --no-first-run \
    --disable-gpu \
    --start-maximized \
    http://localhost:3000 &

echo "Kiosk mode launched at $(date)" >> /home/massey/kiosk.log
