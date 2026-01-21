# VPN Proxy Setup Guide

Route specific application traffic through Unlocator VPN via the reTerminal.

## Architecture

```
┌─────────────────┐      ┌─────────────────────────────────────┐
│   Your Mac      │      │          reTerminal                 │
│                 │      │                                     │
│  Claude Code ───┼──────┼──► SOCKS5 Proxy ──► VPN Tunnel ────┼──► Unlocator
│  Terminal       │ :1080│   (microsocks)    (OpenVPN)        │    Chicago
│                 │      │                                     │
│  Browser ───────┼──────┼──► Same proxy                      │
│  (claude.ai)    │      │                                     │
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

### Option 1: Terminal / Claude Code

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
# VPN Proxy for specific commands
alias vpn-curl='curl --socks5-hostname 192.168.1.76:1080'
alias vpn-wget='wget -e "use_proxy=yes" -e "all_proxy=socks5://192.168.1.76:1080"'

# For Claude Code - route all traffic through VPN
alias claude-vpn='ALL_PROXY=socks5h://192.168.1.76:1080 claude'
```

Then run:
```bash
source ~/.zshrc

# Test it
vpn-curl https://api.ipify.org  # Should show VPN IP

# Run Claude Code through VPN
claude-vpn
```

### Option 2: System-wide Proxy for Specific Apps

Create a shell wrapper script `~/bin/via-vpn`:

```bash
#!/bin/bash
# Run any command through VPN proxy
ALL_PROXY=socks5h://192.168.1.76:1080 \
HTTPS_PROXY=socks5h://192.168.1.76:1080 \
HTTP_PROXY=socks5h://192.168.1.76:1080 \
"$@"
```

```bash
chmod +x ~/bin/via-vpn

# Usage
via-vpn curl https://api.ipify.org
via-vpn claude
via-vpn any-command
```

### Option 3: Browser (Safari/Chrome) for claude.ai

**Chrome with Proxy Extension:**
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
| `/usr/local/bin/vpn-proxy-ctl.sh` | Control script |
| `/usr/local/bin/microsocks` | SOCKS5 proxy binary |
