#!/bin/bash
set -e

echo "=== Setting up VNC Remote Desktop for reTerminal ==="
echo ""

# Check if running in X session
if [ -z "$DISPLAY" ]; then
    echo "⚠️  No X session detected. VNC works best when run from the desktop."
    echo "   This is normal when running via SSH."
fi

# Install x11vnc (better for sharing existing desktop)
echo "📦 Installing x11vnc for desktop sharing..."
sudo apt install -y x11vnc

echo "🔐 Setting up VNC password..."
# Create VNC password
mkdir -p ~/.vnc
echo "Enter a password for VNC access (will be hidden):"
x11vnc -storepasswd ~/.vnc/passwd

echo "🚀 Starting VNC server..."
# Start x11vnc to share the existing desktop (what's showing on LCD)
x11vnc -display :0 -rfbauth ~/.vnc/passwd -shared -forever -loop -noxdamage -repeat -rfbport 5900 -bg

echo "🌐 Starting web VNC client..."
# Start websockify to bridge VNC to web
websockify --daemon --web=/usr/share/novnc/ 6080 localhost:5900

echo ""
echo "✅ VNC Remote Desktop is now running!"
echo ""
echo "🖥️  ACCESS OPTIONS:"
echo ""
echo "Option 1 - Web Browser (Easiest):"
echo "  🌐 Open: http://192.168.1.76:6080/vnc.html"
echo "  🔑 Click Connect, enter your VNC password"
echo ""  
echo "Option 2 - VNC Client on Mac:"
echo "  📱 Use VNC Viewer or Screen Sharing"
echo "  🔗 Connect to: 192.168.1.76:5900"
echo "  🔑 Enter your VNC password"
echo ""
echo "🎯 You'll see the reTerminal LCD desktop including:"
echo "   • Home Assistant kiosk mode"
echo "   • Touch/click interactions work"
echo "   • Real-time desktop sharing"
echo ""
echo "⏹️  TO STOP VNC:"
echo "   pkill x11vnc && pkill websockify"
echo ""
