# Health Dashboard

Comprehensive monitoring dashboard for the reTerminal SmartHome system.

**URL:** `http://YOUR_DEVICE_IP:8088`
**Service:** `health-dashboard.service` (systemd, runs as root)
**Code:** `/home/YOUR_USERNAME/health-dashboard/app.py`
**Auto-refresh:** Every 30 seconds

## Family Status Banner

The top of the dashboard shows four large, colour-coded cards designed for non-technical family members to glance at:

| Card | Green | Amber | Red |
|------|-------|-------|-----|
| **Internet** | Working | Issues (high latency) | DOWN |
| **Wi-Fi** | All satellites UP | — | Satellite(s) DOWN (names which) |
| **Streaming** | All 7 services reachable | Some slow/unreachable | Most unreachable |
| **VPN & Proxy** | VPN + proxy online | — | VPN or proxy down |

If your family says "the Wi-Fi isn't working", they can look at the banner and tell you exactly which card is red.

## Dashboard Cards

### Network & Connectivity

| Card | What it monitors | Key details |
|------|-----------------|-------------|
| **Network Pipeline** | Visual chain: Gateway → ISP → DNS → VPN → Proxy → Streaming | Each node green/red |
| **Orbi Mesh** | Router + 6 satellites with location names and RTT | Backhaul chain shown |
| **Internet Status** | Gateway ping, internet reachability, DNS speed | Distinguishes LAN vs ISP issues |
| **Man Cave Satellite** | Dedicated tracking for the problem satellite | Uptime %, drop count, backhaul info |

### Speed & Performance

| Card | What it monitors | Source |
|------|-----------------|--------|
| **ISP Speed (via Gaming Rig)** | Domestic HK (4-stream), single-stream, UK, EU speeds | Gaming Rig SSH (Intel i5, wired) |
| **VPN Speed (via Tunnel)** | Speed through VPN tunnel | reTerminal speedtest-cli |
| **Speed History** | Bar chart of domestic + international speeds over time | Cron CSV data (4x daily) |
| **Streaming Services** | TCP connect test + latency to 7 platforms | Direct socket test |
| **UK Streaming Routes** | Traceroute with ISP/org names per hop, bottleneck flagging | Via VPN, hop names via Gaming Rig |

### VPN & Proxy

| Card | What it monitors |
|------|-----------------|
| **Main VPN (tun0)** | Interface up, split routes on tun0, US exit IP |
| **UK VPN (tun1)** | Interface up, Apple TV policy rules (2 devices), UK exit IP |
| **SOCKS5 Proxy** | Port 1080 listening, exit IP matches VPN |
| **Adobe VPN (PAC)** | On/off state, **toggle button**, SOCKS5 reachability |

### Infrastructure

| Card | What it monitors |
|------|-----------------|
| **Pi-hole DNS** | Container running, DNS resolution, upstream DNS config |
| **Unlocator SmartDNS** | Both SmartDNS servers (185.37.37.37/39) reachable |
| **Docker Containers** | All 13 expected containers running |
| **Systemd Services** | No failed systemd units |
| **System Health** | CPU temp, memory, disk, load average |
| **Pi-hole Analytics** | Query count, blocked count, block rate |
| **Container Freshness** | Age of each Docker image, flags >90 days |
| **Backup Status** | Last borg backup date, age, repo size |

### Controls

| Card | Actions |
|------|---------|
| **Adobe VPN Toggle** | ON/OFF button — controls Mac PAC proxy via SSH |
| **Service Controls** | Restart buttons for VPN stack, Pi-hole, SOCKS5 proxy, Dashboard |

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/` | GET | Dashboard HTML |
| `/api` | GET | Full JSON status of all checks |
| `/health` | GET | 200/503 for Uptime Kuma |
| `/api/adobe-vpn/on` | POST | Enable Adobe PAC proxy on Mac |
| `/api/adobe-vpn/off` | POST | Disable Adobe PAC proxy on Mac |
| `/api/restart/vpn` | POST | Restart VPN + UK VPN + proxy stack |
| `/api/restart/pihole` | POST | Restart Pi-hole container |
| `/api/restart/proxy` | POST | Restart SOCKS5 proxy |
| `/api/restart/dashboard` | POST | Restart health dashboard |

## Orbi Mesh Topology

```
                    Orbi Router (192.168.1.1)
                    ├── Kitchen (192.168.1.8) ─── 5GHz
                    │   └── Man Cave (192.168.1.33) ─── daisy-chained (Poor)
                    ├── Spare Room (192.168.1.22) ─── 5GHz
                    ├── Margi (192.168.1.23) ─── 5GHz
                    ├── Connor (192.168.1.28) ─── 5GHz
                    └── Master Bedroom (192.168.1.66) ─── 5GHz
```

**Man Cave** is on the roof, daisy-chained through the Kitchen satellite below it. Backhaul status reported as "Poor" by Orbi. The dashboard tracks its uptime separately and logs drops.

## Streaming Services Monitored

| Service | Host tested |
|---------|------------|
| Netflix | www.netflix.com |
| BBC iPlayer | www.bbc.co.uk |
| Apple TV+ | tv.apple.com |
| Disney+ | www.disneyplus.com |
| Amazon Prime | www.primevideo.com |
| HBO Max | www.max.com |
| ITV Player | www.itv.com |

## Speed Test Architecture

Speed tests run from **Gaming Rig** (Intel i5-9400F, wired gigabit) for accurate results. The reTerminal's ARM CPU cannot saturate the network link.

```
Dashboard ──SSH──► Gaming Rig (192.168.1.37)
                     │
                     ├── 4x parallel curl → Cloudflare HK edge (domestic)
                     ├── curl → Linode London (UK international)
                     └── curl → Tele2 (EU international)
```

The cron job (`/etc/cron.d/isp-monitor`) runs the same tests 4x daily and logs to CSV for the speed history chart.

See `docs/NETWORK_PERFORMANCE.md` for full speed test methodology and findings.

## Traceroute Hop Identification

The UK traceroute card looks up the ISP/org name for each hop using ip-api.com (via Gaming Rig for reliability). Hops with latency jumps >50ms are highlighted in red with the owner's name shown inline.

## Service Dependencies

```
health-dashboard.service (root, port 8088)
  ├── reads: Docker, systemd, network interfaces, Pi-hole
  ├── SSH to Mac: Adobe VPN toggle (networksetup)
  ├── SSH to Gaming Rig: Speed tests (curl downloads)
  └── writes: /tmp/adobe-vpn-status
```

## File Reference

| File | Purpose |
|------|---------|
| `/home/YOUR_USERNAME/health-dashboard/app.py` | Dashboard application |
| `/etc/systemd/system/health-dashboard.service` | Systemd service unit |
| `/home/YOUR_USERNAME/isp-monitor/speedtest.csv` | Speed test history |
| `/home/YOUR_USERNAME/isp-monitor/download-tests.csv` | Download test results |
| `/home/YOUR_USERNAME/isp-monitor/traceroute.log` | Traceroute history |
| `/home/YOUR_USERNAME/isp-monitor/mancave-uptime.csv` | Man Cave satellite uptime log |
| `/tmp/adobe-vpn-status` | Adobe VPN state (on/off + timestamp) |
| `/tmp/vpn-bypass.lock` | Lock file for VPN route bypass |
