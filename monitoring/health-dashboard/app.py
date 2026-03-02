#!/usr/bin/env python3
"""
SmartHome Health Dashboard
Functional health checks for all services on the reTerminal.
Port: 8088  — Auto-refreshes every 30s
"""

import subprocess
import json
import time
import socket
import threading
import re
import os
from datetime import datetime
import requests
import psutil
from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
APPLE_TV_IP = "192.168.1.23"
EXPECTED_DNS_SERVERS = ["185.37.37.37", "185.37.39.39"]   # Unlocator SmartDNS
EXPECTED_CONTAINERS = [
    "homeassistant", "hassio_supervisor", "hassio_multicast",
    "hassio_audio", "hassio_dns", "hassio_cli", "hassio_observer",
    "pihole", "grafana", "homepage", "influxdb", "mosquitto", "uptime-kuma",
]
ORBI_DEVICES = {
    "192.168.1.1": "Orbi Router",
    "192.168.1.2": "Orbi Satellite 1",
    "192.168.1.3": "Orbi Satellite 2",
}

# ---------------------------------------------------------------------------
# Background cache
# ---------------------------------------------------------------------------
_results = {}
_results_lock = threading.Lock()
_last_run = 0
CACHE_TTL = 30   # seconds (slow checks like exit-IP are sub-cached internally)

# Exit-IP cache (these are slow external calls)
_exit_ip_cache = {"tun0": None, "tun0_ts": 0, "tun1": None, "tun1_ts": 0,
                  "proxy": None, "proxy_ts": 0}
EXIT_IP_TTL = 90   # seconds


# ---------------------------------------------------------------------------
# Helper utilities
# ---------------------------------------------------------------------------

def run(cmd, timeout=10):
    """Run a shell command, return (stdout, returncode)."""
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True,
                           text=True, timeout=timeout)
        return r.stdout.strip(), r.returncode
    except subprocess.TimeoutExpired:
        return "", 124
    except Exception as e:
        return str(e), 1


def ok(msg="OK"):
    return {"status": "ok", "msg": msg}


def warn(msg):
    return {"status": "warn", "msg": msg}


def err(msg):
    return {"status": "error", "msg": msg}


def get_exit_ip(interface=None, proxy=None, ttl=EXIT_IP_TTL):
    """Fetch exit IP from ipinfo.io with per-key caching."""
    key = proxy if proxy else (interface or "default")
    now = time.time()
    cached_ip = _exit_ip_cache.get(key)
    cached_ts = _exit_ip_cache.get(key + "_ts", 0)
    if cached_ip and now - cached_ts < ttl:
        return cached_ip

    try:
        cmd = "curl -s --max-time 12 https://ipinfo.io"
        if interface:
            cmd += f" --interface {interface}"
        if proxy:
            cmd += f" --proxy socks5h://localhost:1080"
        out, rc = run(cmd, timeout=15)
        if rc == 0 and out:
            data = json.loads(out)
            result = {
                "ip": data.get("ip", "?"),
                "country": data.get("country", "?"),
                "city": data.get("city", "?"),
                "org": data.get("org", "?"),
            }
            _exit_ip_cache[key] = result
            _exit_ip_cache[key + "_ts"] = now
            return result
    except Exception:
        pass
    return None


# ---------------------------------------------------------------------------
# Individual checks
# ---------------------------------------------------------------------------

def check_vpn_main():
    """Main VPN: tun0, routes pinned to tun0, US exit IP."""
    issues = []
    details = {}

    # tun0 interface
    out, _ = run("ip -4 addr show tun0 2>/dev/null")
    ip_match = re.search(r"inet (\S+) peer (\S+)", out)
    if not ip_match:
        return err("tun0 interface is DOWN or has no IP")
    details["tun0_ip"] = ip_match.group(1)
    details["tun0_peer"] = ip_match.group(2).rstrip("/32")

    # Routes must be on tun0
    route_out, _ = run("ip route show | grep -E '0\\.0\\.0\\.0/1|128\\.0\\.0\\.0/1'")
    routes = [l.strip() for l in route_out.splitlines() if l.strip()]
    details["routes"] = routes or ["(none)"]

    bad_routes = [r for r in routes if "tun0" not in r]
    if not routes:
        issues.append("Split routes (0/1, 128/1) missing — all traffic may leak to ISP")
    elif bad_routes:
        issues.append(f"Routes NOT on tun0: {'; '.join(bad_routes)}")

    # Exit IP (US expected)
    ip_info = get_exit_ip(interface=None)
    if ip_info:
        details["exit_ip"] = ip_info["ip"]
        details["exit_country"] = ip_info["country"]
        details["exit_city"] = ip_info["city"]
        if ip_info["country"] not in ("US", "CA", "GB", "NL", "SE", "DE"):
            issues.append(f"Exit IP country unexpected: {ip_info['country']} {ip_info['city']}")
    else:
        details["exit_ip"] = "unavailable"
        issues.append("Could not fetch exit IP")

    if issues:
        return {"status": "error", "msg": "; ".join(issues), "details": details}
    return {"status": "ok", "msg": f"US exit {ip_info['ip']} via tun0", "details": details}


def check_vpn_uk():
    """UK VPN: tun1 up, UK exit IP, Apple TV policy routing in place."""
    issues = []
    details = {}

    # tun1 interface
    out, _ = run("ip -4 addr show tun1 2>/dev/null")
    ip_match = re.search(r"inet (\S+) peer (\S+)", out)
    if not ip_match:
        return err("tun1 interface is DOWN or has no IP")
    details["tun1_ip"] = ip_match.group(1)
    details["tun1_peer"] = ip_match.group(2).rstrip("/32")

    # UK VPN table routing for Apple TV
    rule_out, rc = run(f"ip rule show | grep '{APPLE_TV_IP}.*ukvpn'")
    if rc != 0 or not rule_out.strip():
        issues.append(f"Policy rule missing: {APPLE_TV_IP} → ukvpn table")
    else:
        details["appletv_rule"] = rule_out.strip()

    # ukvpn table default route
    route_out, _ = run("ip route show table ukvpn 2>/dev/null")
    if "default" not in route_out:
        issues.append("ukvpn table has no default route")
    else:
        details["ukvpn_route"] = route_out.strip().splitlines()[0] if route_out else ""

    # UK exit IP via tun1
    ip_info = get_exit_ip(interface="tun1")
    if ip_info:
        details["exit_ip"] = ip_info["ip"]
        details["exit_country"] = ip_info["country"]
        details["exit_city"] = ip_info["city"]
        if ip_info["country"] != "GB":
            issues.append(f"Expected UK exit, got: {ip_info['country']} {ip_info['city']}")
    else:
        details["exit_ip"] = "unavailable"
        issues.append("Could not fetch UK exit IP via tun1")

    if issues:
        return {"status": "error", "msg": "; ".join(issues), "details": details}
    return {"status": "ok",
            "msg": f"UK exit {ip_info['ip']} via tun1 | {APPLE_TV_IP} → ukvpn",
            "details": details}


def check_proxy():
    """SOCKS5 proxy: microsocks on port 1080, exit IP matches tun0."""
    issues = []
    details = {}

    # Is port 1080 listening?
    port_out, _ = run("ss -tlnp | grep ':1080'")
    if not port_out.strip():
        return err("microsocks not listening on port 1080")
    details["listening"] = "port 1080 open"

    # Functional: curl through proxy
    ip_info = get_exit_ip(proxy="socks5h://localhost:1080")
    if ip_info:
        details["proxy_exit_ip"] = ip_info["ip"]
        details["proxy_country"] = ip_info["country"]

        # Should match tun0 exit IP
        tun0_info = get_exit_ip()
        if tun0_info and tun0_info["ip"] != ip_info["ip"]:
            issues.append(
                f"Proxy exit ({ip_info['ip']}) ≠ VPN exit ({tun0_info['ip']}) — routing mismatch"
            )
    else:
        details["proxy_exit_ip"] = "unavailable"
        issues.append("curl through SOCKS5 proxy failed")

    if issues:
        return {"status": "error", "msg": "; ".join(issues), "details": details}
    return {"status": "ok",
            "msg": f"Proxy working → {ip_info['ip']} ({ip_info['country']})",
            "details": details}


def check_pihole():
    """Pi-hole: running, DNS resolving, upstream DNS config."""
    issues = []
    details = {}

    # Container running
    ps_out, _ = run("docker inspect --format '{{.State.Status}}' pihole 2>/dev/null")
    if ps_out.strip() != "running":
        return err("pihole container not running")

    # DNS resolution test
    dig_out, rc = run("dig @127.0.0.1 google.com +short +time=3 +tries=1 2>/dev/null | head -1")
    if rc != 0 or not dig_out.strip():
        issues.append("DNS resolution via Pi-hole (localhost) failed")
        details["dns_resolution"] = "FAILED"
    else:
        details["dns_resolution"] = f"OK ({dig_out.strip()})"

    # Upstream DNS servers configured in Pi-hole
    dns_conf, _ = run(
        "docker exec pihole cat /etc/pihole/setupVars.conf 2>/dev/null | grep PIHOLE_DNS"
    )
    configured_dns = re.findall(r"PIHOLE_DNS_\d+=(\S+)", dns_conf)
    details["upstream_dns"] = configured_dns

    # Check if Unlocator SmartDNS servers are in use
    using_unlocator = any(d in EXPECTED_DNS_SERVERS for d in configured_dns)
    using_google = any(d in ("8.8.8.8", "8.8.4.4", "1.1.1.1") for d in configured_dns)

    if using_unlocator:
        details["dns_note"] = "Unlocator SmartDNS active (geo-unblocking enabled)"
    elif using_google:
        issues.append(
            f"Upstream DNS is Google ({', '.join(configured_dns)}) — "
            f"NOT Unlocator SmartDNS. Streaming geo-unblocking may not work!"
        )
        details["dns_note"] = "WARNING: Using Google DNS, not Unlocator SmartDNS"

    # Stats
    stats_out, _ = run("docker exec pihole pihole -c -j 2>/dev/null")
    try:
        stats = json.loads(stats_out)
        details["queries_today"] = stats.get("dns_queries_today", "?")
        details["blocked_today"] = stats.get("ads_blocked_today", "?")
        details["domains_blocked"] = stats.get("domains_being_blocked", "?")
    except Exception:
        pass

    if issues:
        return {"status": "warn", "msg": "; ".join(issues), "details": details}
    return {
        "status": "ok",
        "msg": (f"DNS OK | {details.get('queries_today','?')} queries today, "
                f"{details.get('blocked_today','?')} blocked"),
        "details": details,
    }


def check_docker():
    """All expected Docker containers running."""
    out, _ = run("docker ps --format '{{.Names}}|{{.Status}}'")
    running = {}
    for line in out.splitlines():
        parts = line.split("|", 1)
        if len(parts) == 2:
            running[parts[0]] = parts[1]

    issues = []
    container_statuses = {}
    for name in EXPECTED_CONTAINERS:
        status = running.get(name)
        if status is None:
            container_statuses[name] = "MISSING"
            issues.append(f"{name}: not found")
        elif "Up" not in status:
            container_statuses[name] = f"STOPPED ({status})"
            issues.append(f"{name}: {status}")
        else:
            container_statuses[name] = status

    extra = [n for n in running if n not in EXPECTED_CONTAINERS]
    if extra:
        for n in extra:
            container_statuses[n] = running[n] + " (unexpected)"

    total = len(EXPECTED_CONTAINERS)
    ok_count = sum(1 for n in EXPECTED_CONTAINERS if running.get(n, "").startswith("Up"))

    if issues:
        return {"status": "error",
                "msg": f"{ok_count}/{total} containers OK; issues: {'; '.join(issues)}",
                "details": container_statuses}
    return {"status": "ok", "msg": f"All {total} containers running",
            "details": container_statuses}


def check_systemd():
    """No failed systemd units."""
    out, _ = run("systemctl --failed --no-legend 2>/dev/null")
    failed = [l.strip() for l in out.splitlines() if l.strip()]
    if failed:
        return {"status": "error",
                "msg": f"{len(failed)} failed unit(s): {', '.join(failed[:5])}",
                "details": {"failed": failed}}
    return {"status": "ok", "msg": "No failed systemd units", "details": {"failed": []}}


def check_system():
    """CPU temp, memory, disk usage."""
    details = {}
    issues = []

    # CPU temperature
    try:
        temps = psutil.sensors_temperatures()
        if temps:
            for chip, sensors in temps.items():
                for s in sensors:
                    if s.current:
                        details["cpu_temp"] = f"{s.current:.1f}°C"
                        if s.current > 80:
                            issues.append(f"CPU temp critical: {s.current:.1f}°C")
                        elif s.current > 70:
                            issues.append(f"CPU temp high: {s.current:.1f}°C")
                        break
                if "cpu_temp" in details:
                    break
    except Exception:
        out, _ = run("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null")
        if out:
            temp_c = int(out) / 1000
            details["cpu_temp"] = f"{temp_c:.1f}°C"
            if temp_c > 80:
                issues.append(f"CPU temp critical: {temp_c:.1f}°C")

    # Memory
    mem = psutil.virtual_memory()
    details["memory"] = f"{mem.percent:.1f}% used ({mem.used // 1024 // 1024}MB / {mem.total // 1024 // 1024}MB)"
    if mem.percent > 90:
        issues.append(f"Memory critical: {mem.percent:.1f}%")
    elif mem.percent > 80:
        issues.append(f"Memory high: {mem.percent:.1f}%")

    # Disk (root)
    disk = psutil.disk_usage("/")
    details["disk_root"] = f"{disk.percent:.1f}% used ({disk.used // 1024 // 1024 // 1024}GB / {disk.total // 1024 // 1024 // 1024}GB)"
    if disk.percent > 90:
        issues.append(f"Disk / critical: {disk.percent:.1f}%")
    elif disk.percent > 80:
        issues.append(f"Disk / high: {disk.percent:.1f}%")

    # Load average
    load = os.getloadavg()
    details["load"] = f"{load[0]:.2f} {load[1]:.2f} {load[2]:.2f}"

    if issues:
        status = "error" if any("critical" in i for i in issues) else "warn"
        return {"status": status, "msg": "; ".join(issues), "details": details}
    return {"status": "ok", "msg": f"Temp {details.get('cpu_temp','?')} | Mem {mem.percent:.0f}% | Disk {disk.percent:.0f}%",
            "details": details}


def check_smartdns():
    """Unlocator SmartDNS: directly query both servers to verify reachability."""
    issues = []
    details = {}
    servers = {
        "185.37.37.37": "primary",
        "185.37.39.39": "secondary",
    }
    for ip, role in servers.items():
        out, rc = run(f"dig @{ip} google.com +short +time=4 +tries=1 2>/dev/null | head -1")
        if rc == 0 and out.strip():
            details[f"{role} ({ip})"] = f"UP — responded with {out.strip()}"
        else:
            issues.append(f"Unlocator {role} ({ip}) not responding")
            details[f"{role} ({ip})"] = "DOWN / timeout"

    if issues:
        return {"status": "error",
                "msg": "; ".join(issues) + " — geo-unblocking may be broken",
                "details": details}
    return {"status": "ok",
            "msg": "Both Unlocator SmartDNS servers reachable",
            "details": details}


def check_orbi():
    """Ping Orbi router and satellites."""
    details = {}
    issues = []

    for ip, name in ORBI_DEVICES.items():
        out, rc = run(f"ping -c 2 -W 1 {ip} 2>/dev/null")
        if rc == 0:
            # Extract round-trip time (Linux: min/avg/max/mdev format)
            m = re.search(r"(?:min/avg/max[^=]*=\s*[\d.]+/)?([\d.]+)/", out)
            if not m:
                m = re.search(r"time=([\d.]+)", out)
            rtt = f"{m.group(1)}ms" if m else "up"
            details[name] = {"ip": ip, "status": "UP", "rtt": rtt}
        else:
            details[name] = {"ip": ip, "status": "DOWN"}
            issues.append(f"{name} ({ip}) not responding to ping")

    # Try Orbi router web UI availability
    out, rc = run("curl -s -I -k --max-time 5 https://192.168.1.1 2>/dev/null | head -1")
    if rc == 0 and ("200" in out or "302" in out or "301" in out):
        details["orbi_web"] = "Admin UI reachable"
    else:
        details["orbi_web"] = "Admin UI unreachable"

    if issues:
        return {"status": "error", "msg": "; ".join(issues), "details": details}
    router_rtt = details.get("Orbi Router", {}).get("rtt", "?")
    return {"status": "ok",
            "msg": f"Router + {len(ORBI_DEVICES) - 1} satellites all UP | Router RTT {router_rtt}",
            "details": details}


# ---------------------------------------------------------------------------
# Aggregate all checks (with threading for speed)
# ---------------------------------------------------------------------------

def run_all_checks():
    """Run all checks concurrently."""
    check_fns = {
        "vpn_main": check_vpn_main,
        "vpn_uk": check_vpn_uk,
        "proxy": check_proxy,
        "pihole": check_pihole,
        "smartdns": check_smartdns,
        "docker": check_docker,
        "systemd": check_systemd,
        "system": check_system,
        "orbi": check_orbi,
    }

    results = {}
    threads = []
    lock = threading.Lock()

    def run_check(name, fn):
        try:
            result = fn()
        except Exception as e:
            result = err(f"Check crashed: {e}")
        with lock:
            results[name] = result

    for name, fn in check_fns.items():
        t = threading.Thread(target=run_check, args=(name, fn))
        t.daemon = True
        threads.append(t)
        t.start()

    for t in threads:
        t.join(timeout=30)

    results["checked_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    return results


def get_cached_results():
    """Return cached results, refreshing if stale."""
    global _last_run
    now = time.time()
    with _results_lock:
        if now - _last_run > CACHE_TTL or not _results:
            # Update in place
            fresh = run_all_checks()
            _results.clear()
            _results.update(fresh)
            _last_run = now
        return dict(_results)


def background_refresher():
    """Continuously refresh checks in the background."""
    while True:
        try:
            fresh = run_all_checks()
            with _results_lock:
                _results.clear()
                _results.update(fresh)
                globals()["_last_run"] = time.time()
        except Exception:
            pass
        time.sleep(CACHE_TTL)


# ---------------------------------------------------------------------------
# HTML Template
# ---------------------------------------------------------------------------

HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="30">
<title>SmartHome Health</title>
<style>
  :root {
    --bg: #0d1117; --surface: #161b22; --border: #30363d;
    --ok: #238636; --ok-light: #2ea043; --ok-text: #56d364;
    --warn: #9e6a03; --warn-light: #bb8009; --warn-text: #e3b341;
    --err: #da3633; --err-light: #f85149; --err-text: #ff7b72;
    --text: #c9d1d9; --muted: #8b949e; --heading: #f0f6fc;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', system-ui, sans-serif; font-size: 14px; }
  header { background: var(--surface); border-bottom: 1px solid var(--border); padding: 16px 24px; display: flex; align-items: center; justify-content: space-between; }
  header h1 { color: var(--heading); font-size: 20px; font-weight: 600; }
  .checked-at { color: var(--muted); font-size: 12px; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(420px, 1fr)); gap: 16px; padding: 16px 24px; }
  .card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; }
  .card-header { display: flex; align-items: center; gap: 10px; padding: 12px 16px; border-bottom: 1px solid var(--border); }
  .card-title { font-weight: 600; color: var(--heading); font-size: 15px; }
  .card-body { padding: 12px 16px; }
  .status-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
  .status-ok   .status-dot { background: var(--ok-text); box-shadow: 0 0 6px var(--ok-text); }
  .status-warn .status-dot { background: var(--warn-text); box-shadow: 0 0 6px var(--warn-text); }
  .status-error .status-dot { background: var(--err-text); box-shadow: 0 0 6px var(--err-text); }
  .status-ok   .card-header { border-left: 3px solid var(--ok-text); }
  .status-warn .card-header { border-left: 3px solid var(--warn-text); }
  .status-error .card-header { border-left: 3px solid var(--err-text); }
  .msg { font-size: 13px; margin-bottom: 10px; }
  .msg.ok   { color: var(--ok-text); }
  .msg.warn { color: var(--warn-text); }
  .msg.err  { color: var(--err-text); }
  .details { border-top: 1px solid var(--border); padding-top: 10px; margin-top: 4px; }
  .detail-row { display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; padding: 3px 0; }
  .detail-key { color: var(--muted); font-size: 12px; white-space: nowrap; }
  .detail-val { color: var(--text); font-size: 12px; text-align: right; word-break: break-all; max-width: 70%; }
  .detail-val.ok   { color: var(--ok-text); }
  .detail-val.warn { color: var(--warn-text); }
  .detail-val.err  { color: var(--err-text); }
  .badge { display: inline-block; padding: 1px 6px; border-radius: 4px; font-size: 11px; font-weight: 600; }
  .badge-ok   { background: var(--ok); color: #fff; }
  .badge-warn { background: var(--warn); color: #fff; }
  .badge-err  { background: var(--err); color: #fff; }
  .container-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 4px; margin-top: 6px; }
  .container-item { display: flex; align-items: center; gap: 5px; font-size: 12px; }
  .dot-sm { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }
  .dot-ok   { background: var(--ok-text); }
  .dot-warn { background: var(--warn-text); }
  .dot-err  { background: var(--err-text); }
  footer { text-align: center; color: var(--muted); font-size: 11px; padding: 16px; }
  .remediation { background: #161b22; border: 1px solid var(--err); border-radius: 4px; padding: 8px 10px; margin-top: 8px; font-family: monospace; font-size: 11px; color: var(--err-text); white-space: pre-wrap; }
</style>
</head>
<body>
<header>
  <h1>🏠 SmartHome Health Dashboard</h1>
  <span class="checked-at">Updated: {{ data.checked_at }} &nbsp;|&nbsp; Auto-refresh 30s</span>
</header>
<div class="grid">

{# ── VPN Main ── #}
{% set s = data.vpn_main %}
<div class="card status-{{ s.status }}">
  <div class="card-header">
    <div class="status-dot"></div>
    <span class="card-title">🌐 Main VPN (tun0 — US)</span>
  </div>
  <div class="card-body">
    <div class="msg {{ 'ok' if s.status=='ok' else ('warn' if s.status=='warn' else 'err') }}">{{ s.msg }}</div>
    {% if s.details %}
    <div class="details">
      {% for k,v in s.details.items() %}
      <div class="detail-row"><span class="detail-key">{{ k }}</span><span class="detail-val">{{ v if v is string else v | join(', ') }}</span></div>
      {% endfor %}
    </div>
    {% endif %}
    {% if s.status == 'error' %}
    <div class="remediation">sudo systemctl restart unlocator-vpn
# Wait 12s, then:
sudo systemctl restart uk-vpn-prime
# Wait 15s, then:
sudo systemctl restart vpn-proxy</div>
    {% endif %}
  </div>
</div>

{# ── UK VPN ── #}
{% set s = data.vpn_uk %}
<div class="card status-{{ s.status }}">
  <div class="card-header">
    <div class="status-dot"></div>
    <span class="card-title">🇬🇧 UK VPN (tun1 — Apple TV)</span>
  </div>
  <div class="card-body">
    <div class="msg {{ 'ok' if s.status=='ok' else ('warn' if s.status=='warn' else 'err') }}">{{ s.msg }}</div>
    {% if s.details %}
    <div class="details">
      {% for k,v in s.details.items() %}
      <div class="detail-row"><span class="detail-key">{{ k }}</span><span class="detail-val">{{ v if v is string else v | join(', ') }}</span></div>
      {% endfor %}
    </div>
    {% endif %}
    {% if s.status == 'error' %}
    <div class="remediation">sudo systemctl restart uk-vpn-prime
# After 15s:
sudo systemctl restart vpn-proxy</div>
    {% endif %}
  </div>
</div>

{# ── SOCKS5 Proxy ── #}
{% set s = data.proxy %}
<div class="card status-{{ s.status }}">
  <div class="card-header">
    <div class="status-dot"></div>
    <span class="card-title">🔀 SOCKS5 Proxy (claude-vpn)</span>
  </div>
  <div class="card-body">
    <div class="msg {{ 'ok' if s.status=='ok' else ('warn' if s.status=='warn' else 'err') }}">{{ s.msg }}</div>
    {% if s.details %}
    <div class="details">
      {% for k,v in s.details.items() %}
      <div class="detail-row"><span class="detail-key">{{ k }}</span><span class="detail-val">{{ v }}</span></div>
      {% endfor %}
    </div>
    {% endif %}
    {% if s.status == 'error' %}
    <div class="remediation">sudo systemctl restart vpn-proxy
# If that fails, restart all:
sudo systemctl restart unlocator-vpn
sleep 12 && sudo systemctl restart uk-vpn-prime
sleep 15 && sudo systemctl restart vpn-proxy</div>
    {% endif %}
  </div>
</div>

{# ── Pi-hole ── #}
{% set s = data.pihole %}
<div class="card status-{{ s.status }}">
  <div class="card-header">
    <div class="status-dot"></div>
    <span class="card-title">🕳️ Pi-hole DNS</span>
  </div>
  <div class="card-body">
    <div class="msg {{ 'ok' if s.status=='ok' else ('warn' if s.status=='warn' else 'err') }}">{{ s.msg }}</div>
    {% if s.details %}
    <div class="details">
      {% for k,v in s.details.items() %}
      {% if v is iterable and v is not string %}
      <div class="detail-row"><span class="detail-key">{{ k }}</span><span class="detail-val {% if k=='upstream_dns' and ('8.8.8.8' in v or '1.1.1.1' in v) %}warn{% endif %}">{{ v | join(', ') }}</span></div>
      {% else %}
      <div class="detail-row"><span class="detail-key">{{ k }}</span><span class="detail-val {% if 'WARNING' in (v|string) %}warn{% endif %}">{{ v }}</span></div>
      {% endif %}
      {% endfor %}
    </div>
    {% endif %}
    {% if s.status == 'warn' and 'Google' in s.msg %}
    <div class="remediation"># Update Pi-hole to use Unlocator SmartDNS:
# In Pi-hole admin → Settings → DNS
# Primary: 185.37.37.37
# Secondary: 185.37.37.38
# (or update docker-compose.yml DNS vars)</div>
    {% endif %}
  </div>
</div>

{# ── Unlocator SmartDNS ── #}
{% set s = data.smartdns %}
<div class="card status-{{ s.status }}">
  <div class="card-header">
    <div class="status-dot"></div>
    <span class="card-title">🌍 Unlocator SmartDNS</span>
  </div>
  <div class="card-body">
    <div class="msg {{ 'ok' if s.status=='ok' else ('warn' if s.status=='warn' else 'err') }}">{{ s.msg }}</div>
    {% if s.details %}
    <div class="details">
      {% for k,v in s.details.items() %}
      <div class="detail-row"><span class="detail-key">{{ k }}</span><span class="detail-val {% if 'DOWN' in (v|string) %}err{% elif 'UP' in (v|string) %}ok{% endif %}">{{ v }}</span></div>
      {% endfor %}
    </div>
    {% endif %}
    {% if s.status == 'error' %}
    <div class="remediation"># SmartDNS servers unreachable — check VPN/internet connectivity
# Verify Pi-hole upstream: Settings → DNS in Pi-hole admin</div>
    {% endif %}
  </div>
</div>

{# ── Docker Containers ── #}
{% set s = data.docker %}
<div class="card status-{{ s.status }}">
  <div class="card-header">
    <div class="status-dot"></div>
    <span class="card-title">🐳 Docker Containers</span>
  </div>
  <div class="card-body">
    <div class="msg {{ 'ok' if s.status=='ok' else ('warn' if s.status=='warn' else 'err') }}">{{ s.msg }}</div>
    {% if s.details %}
    <div class="container-grid">
      {% for name, status in s.details.items() %}
      {% set is_ok = 'Up' in (status|string) %}
      {% set is_missing = 'MISSING' in (status|string) or 'STOPPED' in (status|string) %}
      <div class="container-item">
        <div class="dot-sm {% if is_missing %}dot-err{% elif is_ok %}dot-ok{% else %}dot-warn{% endif %}"></div>
        <span style="font-size:11px; color: {% if is_missing %}var(--err-text){% elif is_ok %}var(--text){% else %}var(--warn-text){% endif %}">{{ name }}</span>
      </div>
      {% endfor %}
    </div>
    {% endif %}
  </div>
</div>

{# ── Systemd ── #}
{% set s = data.systemd %}
<div class="card status-{{ s.status }}">
  <div class="card-header">
    <div class="status-dot"></div>
    <span class="card-title">⚙️ Systemd Services</span>
  </div>
  <div class="card-body">
    <div class="msg {{ 'ok' if s.status=='ok' else ('warn' if s.status=='warn' else 'err') }}">{{ s.msg }}</div>
    {% if s.details and s.details.failed %}
    <div class="details">
      {% for unit in s.details.failed %}
      <div class="detail-row"><span class="detail-key err">✗ {{ unit }}</span><span class="detail-val"><code>journalctl -u {{ unit }} -n 20</code></span></div>
      {% endfor %}
    </div>
    {% endif %}
  </div>
</div>

{# ── System Health ── #}
{% set s = data.system %}
<div class="card status-{{ s.status }}">
  <div class="card-header">
    <div class="status-dot"></div>
    <span class="card-title">💻 System Health</span>
  </div>
  <div class="card-body">
    <div class="msg {{ 'ok' if s.status=='ok' else ('warn' if s.status=='warn' else 'err') }}">{{ s.msg }}</div>
    {% if s.details %}
    <div class="details">
      {% for k,v in s.details.items() %}
      <div class="detail-row"><span class="detail-key">{{ k }}</span><span class="detail-val">{{ v }}</span></div>
      {% endfor %}
    </div>
    {% endif %}
  </div>
</div>

{# ── Orbi ── #}
{% set s = data.orbi %}
<div class="card status-{{ s.status }}">
  <div class="card-header">
    <div class="status-dot"></div>
    <span class="card-title">📡 Netgear Orbi Mesh</span>
  </div>
  <div class="card-body">
    <div class="msg {{ 'ok' if s.status=='ok' else ('warn' if s.status=='warn' else 'err') }}">{{ s.msg }}</div>
    {% if s.details %}
    <div class="details">
      {% for name, info in s.details.items() %}
      {% if info is mapping %}
      <div class="detail-row">
        <span class="detail-key">{{ name }}</span>
        <span class="detail-val {% if info.status=='DOWN' %}err{% else %}ok{% endif %}">
          {{ info.status }}{% if info.rtt is defined %} ({{ info.rtt }}){% endif %} — {{ info.ip }}
        </span>
      </div>
      {% else %}
      <div class="detail-row"><span class="detail-key">{{ name }}</span><span class="detail-val">{{ info }}</span></div>
      {% endif %}
      {% endfor %}
    </div>
    {% endif %}
  </div>
</div>

</div><!-- /grid -->
<footer>reTerminal SmartHome &nbsp;|&nbsp; <a href="/api" style="color:var(--muted)">JSON API</a> &nbsp;|&nbsp; <a href="/health" style="color:var(--muted)">Health endpoint</a></footer>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.route("/")
def dashboard():
    data = get_cached_results()
    return render_template_string(HTML, data=data)


@app.route("/api")
def api():
    return jsonify(get_cached_results())


@app.route("/health")
def health():
    """Returns 200 if critical services OK, 503 otherwise (for Uptime Kuma)."""
    data = get_cached_results()
    critical_ok = (
        data.get("vpn_main", {}).get("status") == "ok"
        and data.get("docker", {}).get("status") != "error"
    )
    code = 200 if critical_ok else 503
    return jsonify({"status": "ok" if critical_ok else "degraded",
                    "checked_at": data.get("checked_at")}), code


# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # Seed cache immediately in background
    t = threading.Thread(target=background_refresher, daemon=True)
    t.start()

    # Do one immediate fetch so first page load isn't empty
    threading.Thread(target=lambda: get_cached_results(), daemon=True).start()

    app.run(host="0.0.0.0", port=8088, debug=False, threaded=True)
