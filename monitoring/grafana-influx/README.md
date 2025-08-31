# Grafana + InfluxDB Monitoring Stack

This directory contains the Docker Compose setup for monitoring your Raspberry Pi with Grafana dashboards and InfluxDB for time-series data storage.

## Quick Start

1. **Setup Environment**:
   ```bash
   cd monitoring/grafana-influx
   cp docker-compose.yml docker-compose.yml.example
   # Edit docker-compose.yml and replace all CHANGE_ME_* passwords
   ```

2. **Start Services**:
   ```bash
   docker compose up -d
   ```

3. **Access Grafana**:
   - URL: http://your-pi-ip:3002
   - Username: admin (first login) or your custom username
   - Password: Whatever you set in GF_SECURITY_ADMIN_PASSWORD

## Services

### InfluxDB (Port 8086)
- **Version**: 1.8
- **Database**: `smarthome`  
- **Data Path**: `./influxdb-data`
- **Users**: 
  - Admin user for management
  - Grafana user for dashboard queries

### Grafana (Port 3002)
- **Version**: 9.5.15
- **Data Path**: `./grafana-data`
- **Features**: 
  - System vitals dashboard
  - InfluxDB data source pre-configured
  - Time zone: Asia/Hong_Kong

## System Vitals Dashboard

The included dashboard monitors:
- **CPU Usage** - Real-time percentage
- **Memory Usage** - RAM utilization percentage  
- **Disk Usage** - Storage space percentage
- **CPU Temperature** - Thermal monitoring

### Dashboard URL
`/d/a342df05-226d-4233-b5e7-f46688260197/reterminal-system-vitals`

### Data Source Requirements
The dashboard expects InfluxDB data in `system_vitals` measurement with:
- Segmented data by `type` field (cpu, memory, disk, temperature)
- Fields: `cpu_usage`, `memory_percent`, `disk_usage_percent`, `cpu_temp`

### Sample Queries
```sql
-- CPU Usage
SELECT mean("cpu_usage") FROM "system_vitals" WHERE "type" = 'cpu' AND $timeFilter GROUP BY time($__interval) fill(null)

-- Memory Usage  
SELECT mean("memory_percent") FROM "system_vitals" WHERE "type" = 'memory' AND $timeFilter GROUP BY time($__interval) fill(null)

-- Disk Usage
SELECT mean("disk_usage_percent") FROM "system_vitals" WHERE "type" = 'disk' AND $timeFilter GROUP BY time($__interval) fill(null)

-- CPU Temperature
SELECT mean("cpu_temp") FROM "system_vitals" WHERE "type" = 'temperature' AND $timeFilter GROUP BY time($__interval) fill(null)
```

## Troubleshooting

### Dashboard Shows "No Data"
1. Check InfluxDB has data: `curl "http://localhost:8086/query?db=smarthome&q=SHOW%20MEASUREMENTS"`
2. Verify data source connection in Grafana
3. Ensure queries include proper `WHERE "type" = 'cpu'` filters

### Login Issues
- Default first login: admin/admin, then set your password
- Check GF_SECURITY_ADMIN_PASSWORD environment variable
- Reset password: `docker exec grafana grafana-cli admin reset-admin-password newpassword`

### Log Issues
If experiencing large log files:
1. Check logrotate configuration: `/etc/logrotate.d/rsyslog`
2. Force log rotation: `sudo logrotate -f /etc/logrotate.conf`
3. Monitor log growth: `sudo du -sh /var/log/*`

## Security Notes

- **Change all default passwords** before deployment
- **Restrict network access** to necessary ports only  
- **Use strong passwords** for all accounts
- **Regular backups** of grafana-data and influxdb-data volumes
- **Keep containers updated** for security patches

## Data Persistence

Both services use Docker volumes for data persistence:
- `./grafana-data` - Dashboards, users, settings
- `./influxdb-data` - Time-series metrics data

## Maintenance

### Backup
```bash
# Stop services
docker compose down

# Backup data
tar -czf backup-$(date +%Y%m%d).tar.gz grafana-data influxdb-data

# Start services  
docker compose up -d
```

### Updates
```bash
docker compose pull
docker compose up -d
```
