# Pi-hole Configuration Reference

**Last updated**: March 2, 2026

This document covers the intended Pi-hole configuration, known gotchas, and how to recover from common problems.

---

## Upstream DNS: Unlocator SmartDNS

Pi-hole is configured to use **Unlocator SmartDNS** as its upstream resolver. This is critical for streaming geo-unblocking — the system is located in Hong Kong and needs DNS-level geo-unblocking for services like Amazon Prime (UK), etc.

| Setting | Value |
|---------|-------|
| Primary DNS | `185.37.37.37` |
| Secondary DNS | `185.37.39.39` |

### ⚠️ Known Bug (Fixed March 2, 2026)

The `docker-compose.yml` had a typo for years: `PIHOLE_DNS_:` (missing number suffix) instead of `PIHOLE_DNS_1:` / `PIHOLE_DNS_2:`. Docker silently ignored the malformed env var, so Pi-hole defaulted to Google DNS (`8.8.8.8` / `8.8.4.4`) whenever the container was recreated. The fix:

```yaml
# WRONG (was silently ignored):
PIHOLE_DNS_: '185.37.37.37;185.37.39.39'

# CORRECT:
PIHOLE_DNS_1: '185.37.37.37'
PIHOLE_DNS_2: '185.37.39.39'
```

### Verifying DNS is correct

```bash
# Check what Pi-hole is actually using:
docker exec pihole cat /etc/pihole/setupVars.conf | grep PIHOLE_DNS

# Expected output:
# PIHOLE_DNS_1=185.37.37.37
# PIHOLE_DNS_2=185.37.39.39
```

The **health dashboard** at `http://YOUR_DEVICE_IP:8088` shows a yellow warning if Pi-hole is using Google DNS instead of Unlocator SmartDNS.

---

## Admin Password

The Pi-hole admin password is **not stored in the compose file** — it's set separately inside the container and persisted in the `etc-pihole/` volume.

### Resetting a forgotten password

```bash
# Remove password (allows login with no password):
docker exec pihole pihole -a -p

# Then set a new password via the web UI at http://YOUR_DEVICE_IP/admin
# Settings → Change Password
```

The password hash is stored in `etc-pihole/setupVars.conf` and is NOT version-controlled (intentionally).

---

## Interface / Listening Settings

**Current setting**: `DNSMASQ_LISTENING: all` ("Permit all origins")

This is intentional and safe for this setup. The alternatives and why we use "all":

| Setting | Description | Verdict |
|---------|-------------|---------|
| Allow only local requests | Only answers queries from directly-connected networks | **Too restrictive** — blocks queries from VPN tunnels (tun0, tun1) and Docker bridge networks |
| Respond only on interface eth0 | Binds to eth0 only | Might block Docker container DNS queries |
| Permit all origins | Answers queries from any interface | **Correct choice** — needed for VPN and Docker compatibility |

The "dangerous" warning on "Permit all origins" only applies to machines directly exposed to the internet. This Pi-hole is behind a Netgear Orbi router with **port 53 not forwarded**, so it is not reachable from the internet.

---

## Conditional Forwarding

**Enable this.** It allows Pi-hole to ask the Orbi router (192.168.1.1) to resolve local device hostnames, so the query log shows friendly names ("AppleTV", "MacBook-Pro") instead of raw IPs.

Settings:
- **Local network**: `192.168.1.0/24`
- **DHCP server (router)**: `192.168.1.1`

---

## Docker Compose Location

**Live**: `/home/massey/pihole-docker/docker-compose.yml`
**Repo**: `docker/pihole/docker-compose.yml`

The `dns:` section in docker-compose (8.8.8.8, 8.8.4.4) is Docker's own resolver for the *container itself* during startup — it is **not** the upstream DNS Pi-hole uses for your network. Don't confuse these two.

---

## Watchdog System

Pi-hole has 3-layer watchdog protection (see `docs/WATCHDOG_SYSTEM.md`):
1. Docker `restart: unless-stopped` — handles container crashes
2. `pihole-watchdog.sh` (runs every 2 min) — handles "running but unhealthy"
3. `pihole-docker.service` — **disabled** (boot race condition; Docker's restart policy handles this)

---

## Manual Restart Procedure

```bash
cd ~/pihole-docker
docker compose restart

# Or full recreate (picks up compose changes):
docker compose down && docker compose up -d

# After restart, verify upstream DNS:
docker exec pihole cat /etc/pihole/setupVars.conf | grep PIHOLE_DNS
```
