#!/bin/bash

# Wait for Home Assistant to be ready
echo "Waiting for Home Assistant to start..."
while ! curl -s http://localhost:8123 > /dev/null; do
    echo "Home Assistant not ready yet, waiting 10 seconds..."
    sleep 10
done

echo "Home Assistant is ready! Launching kiosk mode..."
sleep 5

# Disable screensaver and screen blanking
xset s off
xset -dpms  
xset s noblank

# Launch Chromium in kiosk mode
chromium-browser \
    --kiosk \
    --no-sandbox \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-restore-session-state \
    --disable-features=TranslateUI \
    --disable-ipc-flooding-protection \
    --aggressive-cache-discard \
    --memory-pressure-off \
    --max_old_space_size=100 \
    --disable-background-timer-throttling \
    --disable-renderer-backgrounding \
    --disable-backgrounding-occluded-windows \
    --disable-component-extensions-with-background-pages \
    --disable-dev-shm-usage \
    --no-first-run \
    --fast \
    --fast-start \
    --disable-gpu \
    --disable-features=VizDisplayCompositor \
    http://localhost:8123
