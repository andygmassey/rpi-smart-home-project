# VPN Proxy Setup Guide

Route specific application traffic through Unlocator VPN via the reTerminal.

## Architecture

```
┌─────────────────┐      ┌─────────────────────────────────────┐
│   Your Mac      │      │          reTerminal                 │
│                 │      │                                     │
│  Claude Code ───┼──────┼──► SOCKS5 Proxy ──► VPN Tunnel ────┼──► Unlocator
│  (via Privoxy)  │ :1080│   (microsocks)    (OpenVPN)        │    Chicago
│                 │      │                                     │
│  Claude App ────┼──────┼──► Same proxy (--proxy-server)     │
│  Chrome ────────┼──────┼──► Same proxy (--proxy-server)     │
│                 │      │                                     │
│                 │      │   Kill Switch: Proxy bound to VPN  │
│  Other apps ────┼──────┼──► Direct to Internet (no proxy)   │
│                 │      │   IP - if VPN drops, proxy fails   │
└─────────────────┘      └─────────────────────────────────────┘
```

## VPN Proxy Status

Check status on reTerminal:
```bash
ssh massey@192.168.1.76 "vpn-proxy-ctl.sh status"
```

Output:
```
=== VPN Proxy Status ===

VPN:        CONNECTED (10.90.0.18)
Proxy:      RUNNING (port 1080)
Kill Switch: ENABLED

External IP: 89.187.181.130
```

## Automatic Health Monitoring

A watchdog runs every 2 minutes to ensure the VPN proxy stays healthy:
- Checks VPN connection (tun0 interface)
- Checks proxy is listening on port 1080
- Tests end-to-end connectivity through proxy
- Auto-restarts if issues detected (with cooldowns)

**Check watchdog logs:**
```bash
ssh massey@192.168.1.76 "tail -50 /home/massey/vpn-proxy-watchdog.log"
```

**Watchdog status:**
```bash
ssh massey@192.168.1.76 "systemctl status vpn-proxy-watchdog.timer"
```

## Control Commands (on reTerminal)

```bash
# Start VPN and proxy
vpn-proxy-ctl.sh start

# Stop VPN and proxy
vpn-proxy-ctl.sh stop

# Restart
vpn-proxy-ctl.sh restart

# Check status
vpn-proxy-ctl.sh status

# Test proxy connection
vpn-proxy-ctl.sh test
```

---

## Mac Configuration

### Option 1: Claude Code via Privoxy (Recommended)

Node.js applications like Claude Code don't respect `ALL_PROXY` or `SOCKS5` environment variables directly. The solution is to use Privoxy as an HTTP-to-SOCKS bridge.

**Install Privoxy:**
```bash
brew install privoxy
```

**Configure Privoxy** (`/opt/homebrew/etc/privoxy/config`):
```
# Forward all traffic through reTerminal SOCKS5 proxy
listen-address  127.0.0.1:8118
forward-socks5  /  192.168.1.76:1080  .
```

**Start Privoxy:**
```bash
brew services start privoxy
```

**Add alias to `~/.zshrc`:**
```bash
# Route Claude Code traffic through VPN
alias claude-vpn='HTTPS_PROXY=http://127.0.0.1:8118 HTTP_PROXY=http://127.0.0.1:8118 claude'

# VPN Proxy for curl (direct SOCKS5)
alias vpn-curl='curl --socks5-hostname 192.168.1.76:1080'
```

**Test it:**
```bash
source ~/.zshrc

# Test direct SOCKS5 (should show VPN IP)
vpn-curl https://api.ipify.org

# Run Claude Code through VPN
claude-vpn
```

### Option 2: Claude Desktop App & Chrome (Recommended for GUI apps)

Electron-based apps (Claude desktop, Chrome) support the `--proxy-server` flag for direct SOCKS5 proxy.

**Add aliases to `~/.zshrc`:**
```bash
# Claude desktop app via VPN
alias claude-app-vpn='open -a Claude --args --proxy-server="socks5://192.168.1.76:1080"'

# Chrome via VPN (for claude.ai web)
alias chrome-vpn='open -a "Google Chrome" --args --proxy-server="socks5://192.168.1.76:1080"'
```

**Usage:**
```bash
source ~/.zshrc

# Launch Claude desktop through VPN
claude-app-vpn

# Launch Chrome through VPN
chrome-vpn
```

**Note:** These launch separate instances with VPN routing. Your normal Chrome/Claude sessions remain unaffected.

### Option 3: Browser Extensions

**Chrome with Proxy SwitchyOmega:**
1. Install "Proxy SwitchyOmega" extension
2. Create new profile "VPN"
3. Protocol: SOCKS5, Server: 192.168.1.76, Port: 1080
4. Add rule: `*.anthropic.com` → VPN profile
5. Add rule: `*.claude.ai` → VPN profile

**Safari (System Proxy):**
1. System Preferences → Network → Wi-Fi → Advanced → Proxies
2. Enable "SOCKS Proxy"
3. Server: 192.168.1.76, Port: 1080
4. Note: This affects ALL Safari traffic

### Option 4: Per-Application Proxy (macOS)

For apps that respect system proxy but you want per-app control:

```bash
# Run specific app through proxy
networksetup -setsocksfirewallproxy "Wi-Fi" 192.168.1.76 1080

# Disable when done
networksetup -setsocksfirewallproxystate "Wi-Fi" off
```

---

## Testing

### Quick Test from Mac
```bash
# Without proxy (your normal IP)
curl https://api.ipify.org

# With proxy (VPN IP - should be different)
curl --socks5-hostname 192.168.1.76:1080 https://api.ipify.org
```

### Expected Results
- Normal: Your home IP (e.g., Hong Kong IP)
- Via Proxy: 89.187.181.130 (Unlocator Chicago)

---

## Failover / Kill Switch

The proxy is **bound to the VPN interface IP**. If the VPN disconnects:
- The bound IP disappears
- Proxy connections fail (cannot route)
- **Traffic does NOT leak** to your real IP

This is automatic - no manual kill switch needed.

---

## Troubleshooting

### Proxy not connecting
```bash
# Check if VPN is up
ssh massey@192.168.1.76 "vpn-proxy-ctl.sh status"

# Restart if needed
ssh massey@192.168.1.76 "vpn-proxy-ctl.sh restart"
```

### VPN won't connect
```bash
# Check OpenVPN logs
ssh massey@192.168.1.76 "sudo journalctl -u unlocator-vpn -n 50"
```

### Slow connection
The proxy adds a hop. For latency-sensitive apps, consider:
- Using UDP config (already configured)
- Choosing a closer Unlocator server

### Privoxy issues (Mac)
```bash
# Check if Privoxy is running
brew services list | grep privoxy

# Restart Privoxy
brew services restart privoxy

# Test Privoxy is forwarding correctly
curl -x http://127.0.0.1:8118 https://api.ipify.org
# Should show VPN IP (89.187.181.130)
```

---

## Service Management

### Enable auto-start on boot
```bash
ssh massey@192.168.1.76 "sudo systemctl enable unlocator-vpn vpn-proxy"
```

### Disable auto-start
```bash
ssh massey@192.168.1.76 "sudo systemctl disable unlocator-vpn vpn-proxy"
```

---

## Files on reTerminal

| File | Purpose |
|------|---------|
| `/etc/openvpn/unlocator/client.ovpn` | OpenVPN config |
| `/etc/openvpn/unlocator/auth.txt` | VPN credentials (root only) |
| `/etc/systemd/system/unlocator-vpn.service` | VPN systemd service |
| `/etc/systemd/system/vpn-proxy.service` | Proxy systemd service |
| `/etc/systemd/system/vpn-proxy-watchdog.service` | Watchdog service |
| `/etc/systemd/system/vpn-proxy-watchdog.timer` | Watchdog timer (every 2 min) |
| `/usr/local/bin/vpn-proxy-ctl.sh` | Control script |
| `/usr/local/bin/vpn-proxy-watchdog.sh` | Health check script |
| `/usr/local/bin/microsocks` | SOCKS5 proxy binary |
| `/home/massey/vpn-proxy-watchdog.log` | Watchdog log file |

## Files on Mac

| File | Purpose |
|------|---------|
| `/opt/homebrew/etc/privoxy/config` | Privoxy HTTP-to-SOCKS config |
| `~/.zshrc` | Shell aliases (see below) |
| `~/bin/notebooklm-vpn` | NotebookLM launcher script |
| `~/Applications/NotebookLM VPN.app` | NotebookLM macOS app (clickable) |

### Shell Aliases Summary

Add all of these to `~/.zshrc`:

```bash
# Claude Code (terminal) - via Privoxy
alias claude-vpn='HTTPS_PROXY=http://127.0.0.1:8118 HTTP_PROXY=http://127.0.0.1:8118 claude'

# NotebookLM (Chrome app mode) - via Privoxy
alias notebooklm-vpn='~/bin/notebooklm-vpn'

# Claude desktop app - via macOS Launch Services
alias claude-app-vpn='open -a Claude --args --proxy-server="socks5://192.168.1.76:1080"'

# Chrome browser - via macOS Launch Services
alias chrome-vpn='open -a "Google Chrome" --args --proxy-server="socks5://192.168.1.76:1080"'

# curl via VPN
alias vpn-curl='curl --socks5-hostname 192.168.1.76:1080'
```

---

## NotebookLM VPN App

Google NotebookLM is web-only, but we've created an app-like experience that routes through the VPN.

### Usage

**Option 1 - Click the app:**
- Open `~/Applications/NotebookLM VPN.app` (or find via Spotlight)

**Option 2 - Terminal:**
```bash
notebooklm-vpn
```

### How it works

```
NotebookLM VPN app
       │
       ▼
Chrome (--proxy-server=http://127.0.0.1:8118)
       │
       ▼
Privoxy (127.0.0.1:8118) → reTerminal SOCKS5 (:1080) → OpenVPN → Internet
```

### Features

- **Isolated Chrome profile**: Uses `~/.config/chrome-vpn-profile` - separate from your main Chrome
- **App-like window**: Opens in `--app` mode (no browser chrome)
- **Pre-flight checks**: Alerts if Privoxy or VPN proxy is down
- **Persistent sessions**: Sign in once, stays logged in

### Notes

- First launch requires Google sign-in (fresh profile)
- Uses Privoxy instead of direct SOCKS5 (better Chrome compatibility)
- Works with HK-based Google accounts (tested Feb 2026)
