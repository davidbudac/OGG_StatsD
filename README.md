# Oracle GoldenGate 23ai metrics with StatsD, Telegraf, InfluxDB and Grafana

Demo stack for the blog post
[GoldenGate StatsD + Telegraf](https://blogs.oracle.com/dataintegration/goldengate-statsd-telegraf):
GoldenGate pushes performance metrics over StatsD (UDP 8125) to Telegraf,
Telegraf writes them to InfluxDB 2, and Grafana shows them on a provisioned dashboard.

| Container    | Image                                                                    | Host port |
|--------------|--------------------------------------------------------------------------|-----------|
| ogg234demo   | `container-registry.oracle.com/goldengate/goldengate-oracle-free:latest` | 1055 (HTTPS) |
| db233demoW   | `alexlima/oracle-free:23.3-slim-ogg` (HR schema)                         | 1524      |
| db233demoE   | `alexlima/oracle-free:23.3-slim-ogg` (HR schema)                         | 1525      |
| influxdb     | `influxdb:2.7-alpine`                                                    | 8086      |
| telegraf     | `telegraf:1.30.2`                                                        | 8125/udp  |
| grafana      | `grafana/grafana:10.4.2`                                                 | 3000      |

All passwords are `Welcome##123` (users: `oggadmin` for GoldenGate, `admin` for InfluxDB and Grafana).

## Requirements

- Docker with Compose v2.20+
- ~12 GB RAM and ~15 GB disk (the GoldenGate container reserves 4 CPUs / 8 GB)

## Quick start

```bash
docker compose up -d
./create_replication.sh   # waits for containers, then sets up WEST <-> EAST replication of HR
./enable_statsd.sh        # enables StatsD metrics and restarts the Extracts/Replicats
```

Then open:

- GoldenGate: https://localhost:1055 (self-signed certificate)
- Grafana: http://localhost:3000 → Dashboards → Main Dashboard
- InfluxDB: http://localhost:8086

Generate some changes on the WEST database to see the counters move, e.g.:

```bash
docker exec -i db233demoW sqlplus -s hr/Welcome##123@FREEPDB1 <<'SQL'
update hr.employees set salary = salary where rownum <= 30;
commit;
SQL
```

If port 3000 is already in use: `GRAFANA_PORT=3001 docker compose up -d`.

## Clean up

```bash
docker compose down -v
```
