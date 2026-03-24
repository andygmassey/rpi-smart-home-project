# Network Performance & Speed Testing

How internet speed is measured, what the numbers mean, and why different tests show different results.

## Architecture

```
                    ┌─────────────────────────────┐
                    │          PCCW/HKT            │
                    │    1Gbps Fibre (Netvigator)  │
                    └────────────┬────────────────┘
                                 │
                    ┌────────────▼────────────────┐
                    │      Orbi Router (RBR850)    │
                    │      192.168.1.1             │
                    │      Speed test: ~982 Mbps   │
                    └──┬───────┬───────┬──────┬───┘
                       │       │       │      │
                  Wired │  Wired │  WiFi │  WiFi │
                       │       │       │      │
              ┌────────▼┐ ┌───▼──────┐│ ┌───▼────────┐
              │reTerminal│ │Gaming Rig││ │  Phones /   │
              │Pi CM4    │ │ i5-9400F ││ │  Laptops    │
              │.76       │ │ .37      ││ │  434 Mbps   │
              │          │ │ 519 Mbps ││ │  (WiFi)     │
              │ VPN ─────┤ │ (4-str)  ││ │             │
              │ Proxy    │ │ 161 Mbps ││ │             │
              │ Pi-hole  │ │ (single) ││ │             │
              │ Dashboard│ │ Ubuntu   ││ │             │
              └──────────┘ └──────────┘│ └─────────────┘
                                       │
                              ┌────────▼───────┐
                              │  6 Satellites   │
                              │  (RBS850)       │
                              └────────────────┘
```

## Speed Test Results Summary (17 March 2026)

| Device | Method | Domestic HK | International UK | Notes |
|--------|--------|-------------|-----------------|-------|
| Orbi Router | Built-in test | 982 Mbps | N/A | Tests to PCCW's own server |
| iPhone (WiFi) | Speedtest app | 434 Mbps | N/A | WiFi overhead, HK Ookla server |
| Gaming Rig (wired) | curl, 4 parallel | 519 Mbps | 23 Mbps | Real throughput to Cloudflare |
| Gaming Rig (wired) | curl, single | 161 Mbps | 10–14 Mbps | Single TCP stream |
| reTerminal (wired) | curl, 4 parallel | 130 Mbps | 4–8 Mbps | ARM CPU-limited |
| reTerminal (wired) | speedtest-cli | 2.4 Mbps | N/A | Python tool, CPU-bound on ARM |

### Key Findings

1. **PCCW delivers ~1 Gbps domestically.** The Orbi router confirms this.

2. **WiFi overhead is ~50%.** iPhone gets 434 Mbps over WiFi 6 vs 982 Mbps wired — normal.

3. **Gaming Rig is the accurate test rig.** Intel i5 with wired gigabit gives reliable results: 519 Mbps domestic, 161 Mbps single-stream.

4. **The reTerminal is CPU-limited.** The Raspberry Pi CM4 (quad-core ARM @ 1.5GHz) running VPN encryption, 13 Docker containers, Pi-hole, and the dashboard simultaneously cannot saturate a gigabit link. This is not an ISP or network problem.

5. **speedtest-cli is unreliable on ARM.** It's a Python tool that's CPU-bound on the CM4. Results (2.4 Mbps) do not reflect actual network capacity. Use curl-based parallel download tests instead.

6. **International single-stream throughput is limited by TCP physics.** A single TCP connection over a 190ms RTT (HK → UK) can only push ~20 Mbps due to TCP window scaling and congestion control. This is expected behaviour, not an ISP fault.

## Why Different Speeds?

### TCP Window Scaling & Latency

TCP throughput is limited by: `Throughput ≈ Window Size / RTT`

With a typical TCP window of 64KB and 190ms RTT to London:
- Theoretical max: `64KB / 0.19s ≈ 337 KB/s ≈ 2.7 Mbps`

Modern TCP with window scaling can push this higher, but single-stream throughput to UK servers tops out around 20–30 Mbps from HK. This is physics, not ISP throttling.

**Solution:** Multiple parallel TCP streams (as apps like Netflix actually use) achieve much higher aggregate throughput.

### Multi-Stream vs Single-Stream

| Streams | Domestic (Cloudflare HK) | International (UK) |
|---------|--------------------------|-------------------|
| 1 | 161 Mbps | 10–23 Mbps |
| 4 | 519 Mbps | 40–60 Mbps (estimated) |

Streaming apps use adaptive bitrate with multiple connections, so real-world streaming performance is better than single-stream tests suggest.

### ARM CPU Bottleneck

The reTerminal's CM4 has:
- Quad-core ARM Cortex-A72 @ 1.5 GHz
- Shared with: OpenVPN (AES-256 encryption), 13 Docker containers, Pi-hole DNS, health dashboard, microsocks

CPU becomes the bottleneck before the network does. OpenVPN's AES-256-CBC encryption is particularly expensive on ARM without hardware AES acceleration.

## Speed Test Infrastructure

### Dashboard (live)

The dashboard at `http://192.168.1.76:8088` shows two speed cards:

**ISP Speed (via Gaming Rig):** Runs curl-based download tests from the Gaming Rig (Intel i5, wired). Tests:
- 4 parallel streams to Cloudflare HK edge (domestic speed)
- Single stream to Linode London (UK speed)
- Single stream to Tele2 (EU speed)
- Cached for 30 minutes between runs

**VPN Speed (via Tunnel):** Runs speedtest-cli from reTerminal through the VPN tunnel. Shows what proxied apps (Claude, Adobe, etc.) experience.

### Cron Monitor (4x daily)

Script: `/usr/local/bin/isp-speed-log.sh`
Schedule: 08:00, 12:00, 18:00, 23:00 daily
Cron: `/etc/cron.d/isp-monitor`

Runs from Gaming Rig (SSH) for accurate results:
- Domestic HK speed (4 parallel Cloudflare streams)
- UK download (Linode London)
- EU download (Tele2)
- Traceroute to UK targets (ISP direct, bypasses VPN)

**Data files** in `/home/YOUR_USERNAME/isp-monitor/`:

| File | Content |
|------|---------|
| `speedtest.csv` | Timestamped speed test results |
| `download-tests.csv` | Individual download test results per server |
| `traceroute.log` | Full traceroute output with timestamps |
| `cron.log` | Cron execution log |

### VPN Bypass Method

The cron script temporarily swaps the VPN routes to test ISP-direct:

```bash
# Save current VPN gateway
VPN_GW=$(ip route show | grep '0.0.0.0/1.*tun0' | awk '{print $3}')

# Bypass: route all traffic via LAN gateway
ip route replace 0.0.0.0/1 via 192.168.1.1 dev eth0
ip route replace 128.0.0.0/1 via 192.168.1.1 dev eth0

# ... run tests ...

# Restore: route all traffic via VPN
ip route replace 0.0.0.0/1 via $VPN_GW dev tun0
ip route replace 128.0.0.0/1 via $VPN_GW dev tun0
```

A file lock (`/tmp/vpn-bypass.lock`) prevents the dashboard and cron from colliding.

## Traceroute Analysis (HK → UK)

### Typical path (ISP direct)

```
Hop  IP               Owner              Location        RTT     Jump
1    192.168.1.1      Orbi Router        Home            <1ms    —
2    42.3.47.253      PCCW/HKT           Kwu Tung, HK   1ms     —
3    10.193.208.181   PCCW internal      HK              1ms     —
4    63.218.56.41     PCCW Global        HK              2ms     —
5    63.218.174.110   PCCW Global        HK              3ms     —
6    67.220.128.205   GTT Americas       US handoff      2ms     —
7    213.200.113.214  GTT                London          191ms   +189ms ← transpacific
8    195.72.93.122    GTT                Frankfurt       191ms   —
9    146.70.4.126     M247 Europe        Bucharest       218ms   +27ms
```

### What the hops mean

- **Hops 1–5 (PCCW network):** <3ms, excellent. PCCW's domestic network is fast.
- **Hop 6 (GTT handoff):** PCCW peers with GTT Communications (Tier 1 transit). Traffic leaves PCCW's network here.
- **Hop 7 (+189ms jump):** Transpacific submarine cable. This is the physical distance from HK to the UK/US — 190ms is expected for this path. Cannot be improved without changing physics.
- **Hops 8–9 (GTT → M247):** GTT's European backbone routes through Frankfurt to M247 in Romania. This is the CDN provider for some UK services.

### Is the ISP at fault?

**No.** The 190ms latency is the physical speed of light through submarine cables between HK and London (~18,000 km). PCCW's domestic performance is excellent. The international routing via GTT is standard for a HK ISP.

The streaming buffering issues are caused by:
1. **High latency** (190ms RTT) limiting single-stream TCP throughput
2. **CDN peering** — how specific streaming CDNs connect to PCCW's network
3. **SmartDNS routing** — geo-unblocking adds hops and may route through suboptimal paths

## Orbi Mesh Network

### Satellite Layout

| Location | IP | Backhaul | Status |
|----------|-----|----------|--------|
| Router | 192.168.1.1 | — | Primary |
| Kitchen | 192.168.1.8 | → Router (5 GHz) | Good |
| Spare Room | 192.168.1.22 | → Router (5 GHz) | Good |
| Margi | 192.168.1.23 | → Router (5 GHz) | Good |
| Connor | 192.168.1.28 | → Router (5 GHz) | Good |
| Man Cave | 192.168.1.33 | → Kitchen (5 GHz) | Poor — daisy-chained, roof |
| Master Bedroom | 192.168.1.66 | → Router (5 GHz) | Good |

**Man Cave** is daisy-chained through the Kitchen satellite (physically closest, directly below on the floor beneath). Signal goes through the ceiling. Backhaul status reported as "Poor" by Orbi. This satellite has intermittent connectivity issues.

**Master Bedroom** occasionally shows higher latency (20–25ms vs typical 2–3ms) due to a thick wall between it and the router.

### Apple TV UK VPN Routing

Two Apple TVs are policy-routed through the UK VPN (tun1):

| Device | IP | Connection | Location |
|--------|-----|------------|----------|
| Living Room Apple TV | 192.168.1.21 | WiFi | Router area |
| Man Cave Apple TV | 192.168.1.31 | WiFi | Man Cave satellite (poor backhaul) |

Both IPs have DHCP reservations at the Orbi router to prevent IP changes breaking the routing rules.

## File Reference

### reTerminal

| File | Purpose |
|------|---------|
| `/usr/local/bin/isp-speed-log.sh` | ISP speed monitor (cron, runs from Gaming Rig) |
| `/etc/cron.d/isp-monitor` | Cron schedule (4x daily) |
| `/home/YOUR_USERNAME/isp-monitor/speedtest.csv` | Speed test results CSV |
| `/home/YOUR_USERNAME/isp-monitor/download-tests.csv` | Download test results CSV |
| `/home/YOUR_USERNAME/isp-monitor/traceroute.log` | Traceroute log |
| `/home/YOUR_USERNAME/health-dashboard/app.py` | Dashboard (speed tests via Gaming Rig SSH) |

### Gaming Rig (Ubuntu Server)

| Detail | Value |
|--------|-------|
| IP | 192.168.1.37 |
| OS | Ubuntu Server 24.04 |
| SSH from reTerminal | `ssh -i /home/YOUR_USERNAME/.ssh/id_ed25519 YOUR_USERNAME@192.168.1.37` |
| SSH alias (Mac) | `ssh gamingrig` |
| Motherboard | ASUS PRIME B365M-A |
| CPU | Intel Core i5-9400F @ 2.90GHz (6 cores) |
| GPU | NVIDIA GeForce RTX 2060 12GB |
| RAM | 48 GB |
| Storage | 2x 3.6TB WD Purple (SATA HDD) + 477GB Toshiba XG4 (NVMe SSD) |
| Connection | Wired gigabit to Orbi Router |
| Tools | curl |
