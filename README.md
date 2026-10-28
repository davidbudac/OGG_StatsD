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

Run these commands from this repository, using the same Compose project name and
Compose file(s) used to start the stack (including any `-p` / `--project-name` or
`-f` options). Both options permanently delete the stack's stored data, including
database contents, GoldenGate configuration, InfluxDB metrics, and Grafana state.

### 1. Remove the stack, keep images

```bash
docker compose down --volumes --remove-orphans
```

Stops and removes the project's containers (including containers for services no
longer in the Compose file), its network, the `grafana_data` and `influxdb_data`
volumes, and anonymous volumes attached to the containers. Images stay available
for a faster restart.

### 2. Remove the stack and its images

```bash
docker compose down --volumes --remove-orphans --rmi all
```

Also removes the images used by the services in `compose.yaml`. Starting the
stack again will require downloading them. Docker may refuse to remove an image
still used by another container; check that container before removing it.

Both options leave the repository's bind-mounted configuration files and
dashboards on disk. These commands are scoped to this Compose project; they do
not clear unrelated Docker resources, build cache, or old image tags no longer
referenced by the Compose file.

### If containers remain

`down --volumes` already removes the current project's service containers, but
keeps images. `--remove-orphans` additionally handles services removed or renamed
in this project. To find containers belonging to a different project (for
example, after renaming the repository directory), list the projects and labels:

```bash
docker compose ls --all
docker ps -a --format 'table {{.Names}}\t{{.Label "com.docker.compose.project"}}\t{{.Status}}'
```

Then use the original project name with either cleanup option, for example:

```bash
docker compose -p ORIGINAL_PROJECT_NAME -f compose.yaml down --volumes --remove-orphans --rmi all
```

See the [Docker Compose down reference](https://docs.docker.com/reference/cli/docker/compose/down/)
for the cleanup flags.
