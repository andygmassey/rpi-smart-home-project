# VPN & Proxy Infrastructure

Route application traffic from the Mac through Unlocator VPN tunnels on the reTerminal, with per-app and per-device control.

## Architecture Overview

```
┌─────────────────────────────────────────┐
│              Mac (192.168.1.15)          │
│                                         │
│  Claude Code ──► Privoxy (:8118) ───┐   │
│  NotebookLM ──► Privoxy (:8118) ───┤   │
│  Antigravity ──► Privoxy (:8118) ──┤   │
│                                     │   │
│  Claude App ──► --proxy-server ─────┤   │
│  Chrome ──────► --proxy-server ─────┤   │
│                                     │   │
│  Adobe Apps ──► PAC file (auto) ────┤   │
│  (Photoshop, Illustrator, CC, ...) │   │
│                                     │   │
│  Other apps ──► Direct (no proxy) ──┼── │ ──► Internet (HK IP)
│                                     │   │
└─────────────────────────────────────┼───┘
                                      │
                            LAN :1080 │
                                      ▼
┌─────────────────────────────────────────┐
│        reTerminal (192.168.1.76)        │
│                                         │
│  microsocks (:1080) ──► tun0 ───────────┼──► Unlocator US (LA)
│   (SOCKS5, bound to VPN IP)            │    Exit: US IP
│                                         │
│  tun0 ─── Main VPN (all traffic) ──────┼──► Unlocator US
│  tun1 ─── UK VPN (Apple TV only) ──────┼──► Unlocator UK (London)
│                                         │
│  Policy routing:                        │
│    192.168.1.23 (Apple TV) ──► tun1     │
│    Everything else ──► tun0             │
│                                         │
└─────────────────────────────────────────┘
```

---

## Dual VPN Tunnels

### tun0 — Main VPN (US)

All reTerminal traffic routes through this tunnel. The SOCKS5 proxy also exits here.

| Setting | Value |
|---------|-------|
| Config | `/etc/openvpn/unlocator/client.ovpn` |
| Protocol | UDP |
| Cipher | AES-256-CBC, SHA512, tls-auth |
| Servers | `us-lax01`, `us-nyc01`, `us-mia01`, `us-chi01`, `nl-ams01` (random) |
| Credentials | `/etc/openvpn/unlocator/auth.txt` |
| Routing | `route-nopull` + `route-up /usr/local/bin/setup-main-vpn-routes.sh` |
| Systemd | `unlocator-vpn.service` (restart on-failure, 5s delay) |

**Route setup** (`setup-main-vpn-routes.sh`):
- Adds `0.0.0.0/1` and `128.0.0.0/1` via tun0 peer IP (covers all traffic)
- Adds VPN server bypass route via LAN gateway (`192.168.1.1`) to prevent routing loop
- Peer IP extracted from `$ifconfig_remote` env var set by OpenVPN

### tun1 — UK VPN (Apple TV)

Only Apple TV (192.168.1.23) traffic routes here, via policy routing.

| Setting | Value |
|---------|-------|
| Config | `/etc/openvpn/client/uk-vpn.conf` |
| Server | `gb-lon01.unlocator.com` |
| Routing | `route-nopull` + `route-up /usr/local/bin/setup-uk-vpn-routes.sh` |
| Systemd | `uk-vpn-prime.service` (forking, 10s delay for routing setup) |

**Route setup** (`setup-uk-vpn-routes.sh`):
- Creates/populates routing table `ukvpn` (ID 100 in `/etc/iproute2/rt_tables`)
- Adds policy rule: `from 192.168.1.23 lookup ukvpn` (priority 32765)
- Default route in ukvpn table → tun1 gateway
- LAN route (`192.168.1.0/24 dev eth0`) in ukvpn table for local access
- NAT masquerade for Apple TV outbound on tun1

**Additional scripts:**
- `/usr/local/bin/setup-prime-routing.sh` — legacy startup script (called by uk-vpn-prime ExecStart, waits up to 30s for tun1)
- `/usr/local/bin/cleanup-prime-routing.sh` — removes policy rule, flushes ukvpn table, removes NAT (called on service stop)

---

## SOCKS5 Proxy (microsocks)

The bridge between the Mac and the VPN. All Mac proxy methods ultimately go through this.

| Setting | Value |
|---------|-------|
| Binary | `/usr/local/bin/microsocks` |
| Listen | `0.0.0.0:1080` |
| Bind IP | tun0 internal IP (e.g. `10.90.0.6`) — extracted at startup |
| User | `nobody:nogroup` |
| Systemd | `vpn-proxy.service` |

**Service dependencies:**
- `Requires=unlocator-vpn.service` / `BindsTo=unlocator-vpn.service`
- `ExecStartPre` waits for tun0 to have an inet address before launching
- If unlocator-vpn stops, vpn-proxy stops automatically

**Kill switch:** microsocks binds its outbound socket to the VPN's internal IP. If the VPN drops, that IP disappears and all proxy connections fail — traffic never leaks to the real IP.

### Service startup order

```
unlocator-vpn (tun0 up, routes set)
    │
    ├──► vpn-proxy (waits for tun0 IP, starts microsocks)
    │
    └──► uk-vpn-prime (independent, tun1 up, Apple TV routing)
              │
              └──► setup-prime-routing.sh (after 10s delay)
```

**Restart order** (if manually restarting):
```bash
sudo systemctl restart unlocator-vpn
sleep 12
sudo systemctl restart uk-vpn-prime
sleep 15
sudo systemctl restart vpn-proxy
```

---

## Mac Proxy Methods

### 1. Privoxy (HTTP-to-SOCKS bridge)

For apps that support `HTTP_PROXY`/`HTTPS_PROXY` but not SOCKS5 directly (Node.js, Electron with env vars).

| Setting | Value |
|---------|-------|
| Config | `/opt/homebrew/etc/privoxy/config` |
| Listen | `127.0.0.1:8118` |
| Forward | `forward-socks5 / 192.168.1.76:1080 .` |
| Service | `brew services start privoxy` |

**Chain:** App → Privoxy (localhost:8118) → microsocks (reTerminal:1080) → tun0 → Internet

**Used by:** `claude-vpn`, `notebooklm-vpn`, `antigravity-vpn`

### 2. Direct SOCKS5 (`--proxy-server` flag)

For Electron/Chrome apps that accept the flag at launch.

**Chain:** App → microsocks (reTerminal:1080) → tun0 → Internet

**Used by:** `claude-app-vpn`, `chrome-vpn`

### 3. PAC File (macOS Auto Proxy)

For apps that use macOS CFProxy API (Adobe apps, Safari, native apps). Routes only matching domains through the proxy; everything else goes direct.

| Setting | Value |
|---------|-------|
| PAC file | `~/.config/proxy/adobe-vpn.pac` |
| Proxy | `SOCKS5 192.168.1.76:1080; DIRECT` |
| Toggle | `adobe-vpn-on` / `adobe-vpn-off` |
| macOS API | `networksetup -setautoproxyurl "Wi-Fi" "file://..."` |

**Chain:** Adobe App → macOS CFProxy → PAC lookup → SOCKS5 (reTerminal:1080) → tun0 → Internet

**DNS privacy:** `SOCKS5` (not `SOCKS`) tells the client to resolve DNS remotely through the proxy, preventing DNS leaks.

**Fallback:** `; DIRECT` after the SOCKS5 entry means Adobe apps still work if the proxy is down (at the cost of privacy). Remove the fallback for strict kill-switch behavior.

#### Adobe domains routed through proxy

**Core services:**
`.adobe.com`, `.adobelogin.com`, `.adobe.io`, `.adobesc.com`, `.adobecc.com`, `.creativecloud.com`, `.behance.net`, `.typekit.net`, `.adobeexchange.com`

**Analytics/tracking (privacy-critical):**
`.demdex.net`, `.omniture.com`, `.2o7.net`, `.adobedtm.com`, `.adobedc.net`, `.adobetag.com`, `.everesttech.net`

**Media:**
`.scene7.com`, `.ftcdn.net`

#### First-time use (prevent leaks from cached connections)

```bash
adobe-vpn-on      # Kills Adobe procs, flushes DNS, clears caches, enables PAC
adobe-vpn-status  # Verify IPs differ before launching apps
# Then launch Creative Cloud / Photoshop / etc.
```

The `adobe-vpn-on` script automatically:
1. Kills all Adobe background processes (CCXProcess, CCLibrary, AdobeIPCBroker, Core Sync, etc.)
2. Flushes macOS DNS cache (if sudo available)
3. Clears Adobe connection caches (`~/Library/Caches/com.adobe.*`, `~/Library/Caches/Adobe*`)
4. Enables the PAC file on Wi-Fi
5. Pushes status to the health dashboard on the reTerminal

---

## Shell Aliases (`~/.zshrc`)

```bash
# Claude Code (terminal) — via Privoxy
alias claude-vpn='HTTPS_PROXY=http://127.0.0.1:8118 HTTP_PROXY=http://127.0.0.1:8118 claude'

# NotebookLM (Chrome app mode) — via Privoxy
alias notebooklm-vpn='~/bin/notebooklm-vpn'

# Google Antigravity IDE — via Privoxy
alias antigravity-vpn='~/bin/antigravity-vpn'

# Claude desktop app — direct SOCKS5
alias claude-app-vpn='open -a Claude --args --proxy-server="socks5://192.168.1.76:1080"'

# Chrome browser — direct SOCKS5
alias chrome-vpn='open -a "Google Chrome" --args --proxy-server="socks5://192.168.1.76:1080"'

# curl via VPN
alias vpn-curl='curl --socks5-hostname 192.168.1.76:1080'

# Adobe apps — PAC file toggle
alias adobe-vpn-on='~/.local/bin/adobe-vpn-on'
alias adobe-vpn-off='~/.local/bin/adobe-vpn-off'
alias adobe-vpn-status='~/.local/bin/adobe-vpn-status'
```

---

## Health Dashboard

The health dashboard at `http://192.168.1.76:8088` monitors all VPN/proxy infrastructure with auto-refresh every 30s.

### VPN/proxy checks

| Card | What it checks |
|------|---------------|
| Main VPN (tun0) | Interface up, split routes on tun0, US exit IP |
| UK VPN (tun1) | Interface up, Apple TV policy rule, ukvpn table, UK exit IP |
| SOCKS5 Proxy | Port 1080 listening, exit IP matches tun0 |
| Adobe VPN (PAC) | On/off state, SOCKS5 reachability, **toggle button** |

### Adobe VPN toggle

The Adobe VPN card has an **ON/OFF button** that remotely controls the Mac's PAC proxy setting via SSH (reTerminal → Mac reverse SSH).

**How it works:**
- Dashboard API endpoint: `POST /api/adobe-vpn/on` or `POST /api/adobe-vpn/off`
- Executes `networksetup` on the Mac via SSH (reTerminal → Mac reverse SSH)
- Updates `/tmp/adobe-vpn-status` on the reTerminal for state tracking
- SSH key: `/home/YOUR_USERNAME/.ssh/id_ed25519` (ed25519, comment: `reterminal-to-mac`)

**Note:** The dashboard toggle does not kill Adobe processes or flush DNS — it only toggles the PAC file. For a clean first-time enable (with process kill + cache clear), use `adobe-vpn-on` from the Mac terminal.

### API endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/` | GET | Dashboard HTML |
| `/api` | GET | Full JSON status |
| `/health` | GET | 200/503 for Uptime Kuma |
| `/api/adobe-vpn/on` | POST | Enable PAC proxy on Mac |
| `/api/adobe-vpn/off` | POST | Disable PAC proxy on Mac |

---

## Testing & Verification

### Quick IP comparison

```bash
# Direct IP (HK)
curl https://ifconfig.me

# Via SOCKS5 proxy (US)
curl --socks5-hostname 192.168.1.76:1080 https://ifconfig.me

# Via Privoxy (US, same as above)
curl -x http://127.0.0.1:8118 https://ifconfig.me
```

### Adobe VPN verification

```bash
adobe-vpn-status
# Should show:
#   Auto Proxy: Enabled
#   microsocks: reachable
#   Direct IP ≠ Proxied IP
```

### Monitor Adobe proxy traffic

```bash
# On the Mac — watch connections to the SOCKS5 proxy
sudo tcpdump -i en0 -n host 192.168.1.76 and port 1080
```

### On the reTerminal

```bash
# VPN interfaces
ip -4 addr show tun0   # Main VPN
ip -4 addr show tun1   # UK VPN

# Routes
ip route show | grep -E '0\.0\.0\.0/1|128\.0\.0\.0/1'  # Should be on tun0
ip route show table ukvpn                                # Apple TV → tun1

# Policy rules
ip rule show | grep ukvpn    # 32765: from 192.168.1.23 lookup ukvpn

# Proxy
ss -tlnp | grep 1080         # microsocks listening

# Exit IPs
curl -s https://ipinfo.io                                  # tun0 exit
curl -s --interface tun1 https://ipinfo.io                 # tun1 exit
curl -s --proxy socks5h://localhost:1080 https://ipinfo.io # proxy exit
```

---

## Troubleshooting

### Proxy not connecting from Mac

```bash
# 1. Check SOCKS5 reachability
nc -z -w3 192.168.1.76 1080 && echo OK || echo UNREACHABLE

# 2. Check VPN on reTerminal
ssh reterminal "systemctl status unlocator-vpn vpn-proxy"

# 3. Restart the stack
ssh reterminal "sudo systemctl restart unlocator-vpn && sleep 12 && sudo systemctl restart vpn-proxy"
```

### Adobe apps not routing through proxy

```bash
# 1. Check PAC is enabled
networksetup -getautoproxyurl "Wi-Fi"

# 2. If enabled but leaking: kill cached connections
adobe-vpn-on   # Does full kill + flush + re-enable

# 3. Verify with tcpdump
sudo tcpdump -i en0 -n host 192.168.1.76 and port 1080
# Should see SYN packets when Adobe apps make requests
```

### VPN exit IP unexpected

```bash
# Check routes haven't been overwritten
ssh reterminal "ip route show | grep -E '0\.0\.0\.0/1|128\.0\.0\.0/1'"
# Both should say "dev tun0"

# If routes are missing or on wrong interface, restart VPN
ssh reterminal "sudo systemctl restart unlocator-vpn"
```

### Apple TV not routing through UK VPN

```bash
# Check policy rule exists
ssh reterminal "ip rule show | grep 192.168.1.23"

# Check ukvpn table has default route
ssh reterminal "ip route show table ukvpn"

# Restart UK VPN
ssh reterminal "sudo systemctl restart uk-vpn-prime"
```

### Privoxy not forwarding (Mac)

```bash
# Check if running
brew services list | grep privoxy

# Restart
brew services restart privoxy

# Test chain
curl -x http://127.0.0.1:8118 https://ifconfig.me
# Should show VPN IP
```

### Dashboard Adobe toggle not working

```bash
# Test reverse SSH manually
ssh reterminal "ssh -i /home/YOUR_USERNAME/.ssh/id_ed25519 YOUR_MAC_USER@YOUR_MAC_IP echo ok"

# Check Mac Remote Login is enabled
# System Settings → General → Sharing → Remote Login

# Check dashboard logs
ssh reterminal "sudo journalctl -u health-dashboard --since '5 min ago' --no-pager | tail -20"
```

---

## File Reference

### reTerminal

| File | Purpose |
|------|---------|
| `/etc/openvpn/unlocator/client.ovpn` | Main VPN config (US) |
| `/etc/openvpn/unlocator/auth.txt` | VPN credentials (root only) |
| `/etc/openvpn/client/uk-vpn.conf` | UK VPN config |
| `/usr/local/bin/setup-main-vpn-routes.sh` | tun0 route pinning (called by OpenVPN) |
| `/usr/local/bin/setup-uk-vpn-routes.sh` | tun1 + ukvpn table setup (called by OpenVPN) |
| `/usr/local/bin/setup-prime-routing.sh` | Legacy Apple TV routing (called by systemd) |
| `/usr/local/bin/cleanup-prime-routing.sh` | Apple TV routing teardown |
| `/usr/local/bin/microsocks` | SOCKS5 proxy binary |
| `/etc/systemd/system/unlocator-vpn.service` | Main VPN service |
| `/etc/systemd/system/uk-vpn-prime.service` | UK VPN + Apple TV routing |
| `/etc/systemd/system/vpn-proxy.service` | SOCKS5 proxy service |
| `/home/YOUR_USERNAME/health-dashboard/app.py` | Health dashboard (port 8088) |
| `/tmp/adobe-vpn-status` | Adobe VPN state file (written by toggle) |

### Mac

| File | Purpose |
|------|---------|
| `/opt/homebrew/etc/privoxy/config` | HTTP-to-SOCKS bridge config |
| `~/.config/proxy/adobe-vpn.pac` | PAC file for Adobe domain routing |
| `~/.local/bin/adobe-vpn-on` | Enable PAC + kill Adobe + flush DNS |
| `~/.local/bin/adobe-vpn-off` | Disable PAC proxy |
| `~/.local/bin/adobe-vpn-status` | Show proxy state and IP comparison |
| `~/bin/notebooklm-vpn` | NotebookLM VPN launcher |
| `~/bin/antigravity-vpn` | Antigravity VPN launcher |
| `~/.zshrc` | Shell aliases for all VPN commands |
