# OpenClaw Team Docker Stack

Current version: see [`VERSION`](VERSION). Release notes: [`CHANGELOG.md`](CHANGELOG.md).

A Docker Compose package for running six Ubuntu-based OpenClaw role containers, each with the OpenClaw CLI pre-installed and its own supervised gateway.

The downloadable package is bundled as [`openclaw-docker.zip`](openclaw-docker.zip).

## What's in the image (1.1.1)

- **Ubuntu 24.04** base
- **Node.js 22 LTS** (NodeSource)
- **OpenClaw CLI** pre-installed globally (`npm install -g openclaw@${OPENCLAW_VERSION}`, default `latest`)
- **OpenJDK 21**, Python 3, Git, build-essential, and the usual Linux tooling
- A non-root `openclaw` user (UID 1000) with passwordless sudo

## Roles and ports

Each role runs its own gateway under an isolated profile (`~/.openclaw-<role>`). All ports are bound to `127.0.0.1` only.

| Container | Purpose | Gateway (host) | SSH (host, off by default) |
|---|---|---|---|
| `openclaw-architect` | Architecture, requirements, governance | `127.0.0.1:18791` | `127.0.0.1:2221` |
| `openclaw-designer` | UX flows, UI specifications, prototypes | `127.0.0.1:18792` | `127.0.0.1:2222` |
| `openclaw-developer` | Implementation, integration, build automation | `127.0.0.1:18793` | `127.0.0.1:2223` |
| `openclaw-qc` | Test planning, validation, release gates | `127.0.0.1:18794` | `127.0.0.1:2224` |
| `openclaw-operator` | Deployment, monitoring, incident response | `127.0.0.1:18795` | `127.0.0.1:2225` |
| `openclaw-pa` | Coordination, summaries, task tracking | `127.0.0.1:18796` | `127.0.0.1:2226` |

Inside each container the gateway always listens on `OPENCLAW_GATEWAY_PORT` (default `18789`).

## Workspace model

Each role container has:

- A **private persistent workspace** at `/workspace/role` (volume `openclaw_<role>`)
- A **shared collaboration workspace** at `/workspace/shared` (volume `openclaw_shared`)
- A **role configuration** mounted read-only at `/opt/openclaw/role` (from `config/roles/<role>/`)
- **Shared bootstrap assets** mounted read-only at `/opt/openclaw/bootstrap`
- A **per-role OpenClaw profile** at `~/.openclaw-<role>` (volume `openclaw_profile_<role>`) — config, sessions, secrets, cron jobs

## Quick start

```bash
sudo apt-get update
sudo apt-get install -y unzip
unzip openclaw-docker.zip
cd openclaw-docker
chmod +x scripts/*.sh docker/base/entrypoint.sh
./scripts/openclaw.sh init
./scripts/openclaw.sh build
./scripts/openclaw.sh up
./scripts/openclaw.sh ps
./scripts/openclaw.sh gateway status   # should show 6x UP
```

If Docker is not installed:

```bash
chmod +x scripts/install-docker-ubuntu.sh
./scripts/install-docker-ubuntu.sh
newgrp docker
```

If `docker compose` is unavailable:

```bash
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
```

## Upgrading from 1.1.0 to 1.1.1

The 1.1.1 fix supervises the gateway with a detached watchdog so it survives entrypoint exit. **No data wipe is needed** — your workspace and OpenClaw profile volumes are preserved.

```bash
cd openclaw-linux-docker
git pull
unzip -o openclaw-docker.zip            # overwrite source files (in-place)
cd openclaw-docker
./scripts/openclaw.sh down              # stop containers; volumes KEPT
./scripts/openclaw.sh build             # rebuild image with the watchdog fix
./scripts/openclaw.sh up
./scripts/openclaw.sh gateway status    # 6x UP and stay up
```

`down` keeps your data. Only `docker compose down -v` deletes volumes — don't run that unless you want a clean slate.

## Helper script reference

The wrapper script `scripts/openclaw.sh` works with both `docker compose` (plugin) and legacy `docker-compose`.

### Stack lifecycle
```bash
./scripts/openclaw.sh init             # create .env from .env.example
./scripts/openclaw.sh build            # build the base image
./scripts/openclaw.sh up               # start all roles (detached)
./scripts/openclaw.sh down             # stop & remove containers (volumes kept)
./scripts/openclaw.sh restart          # restart all containers
./scripts/openclaw.sh ps               # show service status
./scripts/openclaw.sh logs [role]      # follow logs (all or one role)
./scripts/openclaw.sh health           # workspace + gateway sanity check
./scripts/openclaw.sh version          # show release + node + openclaw versions
```

### Per-role shell access
```bash
./scripts/openclaw.sh shell architect
./scripts/openclaw.sh shell designer
./scripts/openclaw.sh shell developer
./scripts/openclaw.sh shell qc
./scripts/openclaw.sh shell operator
./scripts/openclaw.sh shell pa
```

### Gateway management
```bash
./scripts/openclaw.sh gateway status                # UP/DOWN per role
./scripts/openclaw.sh gateway logs developer        # tail one role's gateway log
./scripts/openclaw.sh gateway restart               # restart gateway in all roles
./scripts/openclaw.sh gateway restart developer     # restart one role only
```

`gateway restart` sends SIGTERM to the gateway PID; the watchdog respawns it automatically.

### Backup & restore
```bash
./scripts/openclaw.sh backup           # writes backups/openclaw-volumes-<ts>.tar.gz
```

The backup includes all role workspaces, the shared workspace, and all per-role profile volumes.

## Inside-the-container shortcuts

When you `shell` into a role container, these aliases are pre-bound to the role's profile (`--profile <role>`):

```bash
oc           # alias for: openclaw --profile <role>
oc-gw        # alias for: openclaw --profile <role> gateway
oc-logs      # alias for: tail -f /var/log/openclaw/gateway.log
crole        # cd /workspace/role
cshared      # cd /workspace/shared
```

So inside e.g. the developer container you can run `oc plugins list`, `oc-gw status`, `oc doctor`, etc.

## Gateway internals

The gateway is launched by `entrypoint.sh` through a watchdog process at `/usr/local/bin/openclaw-gateway-watchdog`:

- Runs as the `openclaw` user, detached via `runuser + setsid + nohup` into its own session and process group (immune to SIGHUP from entrypoint teardown)
- Loops: spawn `openclaw --profile <role> gateway run` → `wait` → log exit code → sleep `OPENCLAW_GATEWAY_RESTART_DELAY` (default 5s) → respawn
- PID files: `/var/run/openclaw/watchdog.pid`, `/var/run/openclaw/gateway.pid`
- Logs: `/var/log/openclaw/gateway.log` (gateway stdout/stderr) and `/var/log/openclaw/watchdog.log` (supervisor events)
- Stops cleanly on SIGTERM/SIGINT (kills the gateway, removes PID files, exits)

The container's CMD is still `sleep infinity` and the watchdog is a separate detached process — not PID 1 — so a crashed gateway never affects shell-in access.

To disable the gateway entirely set `ENABLE_GATEWAY=false` in `.env` and rebuild.

## Configuration (`.env`)

Initialize once with `./scripts/openclaw.sh init`. Key entries:

| Variable | Default | Purpose |
|---|---|---|
| `OPENCLAW_UID` / `OPENCLAW_GID` | `1000` | UID/GID for the `openclaw` user inside containers |
| `OPENCLAW_TZ` | `Asia/Hong_Kong` | Timezone (build + runtime) |
| `OPENCLAW_VERSION` | `latest` | Pinned OpenClaw npm version (build-time) |
| `NODE_MAJOR` | `22` | Node.js major version from NodeSource (build-time) |
| `OPENCLAW_IMAGE` | `openclaw-ubuntu-agent:24.04` | Image tag |
| `ENABLE_GATEWAY` | `true` | Start the per-role gateway on container start |
| `OPENCLAW_GATEWAY_PORT` | `18789` | Gateway port inside the container |
| `OPENCLAW_GATEWAY_RESTART_DELAY` | `5` | Watchdog backoff (seconds) before respawning a dead gateway |
| `GW_PORT_<ROLE>` | `18791`-`18796` | Host port mapping per role |
| `ENABLE_SSH` | `false` | Enable in-container sshd |
| `SSH_PORT_<ROLE>` | `2221`-`2226` | Host SSH port per role |

Build-time vars (`OPENCLAW_VERSION`, `NODE_MAJOR`, `OPENCLAW_TZ`, UID/GID) require `./scripts/openclaw.sh build` to take effect. Runtime vars take effect on `restart`.

## Verifying the fix

```bash
./scripts/openclaw.sh gateway status     # all 6 should show UP

./scripts/openclaw.sh shell developer
ls /var/run/openclaw/                     # watchdog.pid + gateway.pid
ps -ef | grep -E 'openclaw|sleep'         # sleep (PID 1) + watchdog + gateway
exit

# Gateway should still be running after exit
./scripts/openclaw.sh gateway status

# Stress test: kill the gateway directly, watchdog should respawn within ~6s
docker exec openclaw-developer bash -c 'kill -TERM $(cat /var/run/openclaw/gateway.pid)'
sleep 7
./scripts/openclaw.sh gateway status     # still UP
```

## Troubleshooting

### `gateway status` shows DOWN for a role
1. Tail the watchdog log: `./scripts/openclaw.sh shell <role>` then `tail -100 /var/log/openclaw/watchdog.log`. It records each spawn attempt and the gateway exit code.
2. Tail the gateway log: `./scripts/openclaw.sh gateway logs <role>`.
3. Run the OpenClaw self-check inside the container: `oc doctor` (alias for `openclaw --profile <role> doctor`).
4. If the gateway needs first-run setup, run `oc configure` — the watchdog will pick it up on the next iteration; no rebuild required.

### Build fails with `groupadd: GID '1000' already exists`
Already handled — the Dockerfile reuses the existing UID/GID. Make sure you have the latest zip.

### `docker compose` not found
Install the Compose plugin (`sudo apt-get install -y docker-compose-plugin`) or use the legacy package (`docker-compose`). The helper script auto-detects both.

### Permission denied on `docker ps`
```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

### Want to fully reset a single role's OpenClaw profile
```bash
./scripts/openclaw.sh down
docker volume rm openclaw_openclaw_profile_<role>
./scripts/openclaw.sh up
```
This wipes only that role's `~/.openclaw-<role>`. Workspace volumes are untouched.

## Documentation

- [`CHANGELOG.md`](CHANGELOG.md) — version history and release notes
- [`FAQ.md`](FAQ.md) — pre-flight checks and common issues (inside the zip)
- [`DEPLOYMENT.md`](DEPLOYMENT.md) — deployment instructions (inside the zip)
- [`USAGE.md`](USAGE.md) — role and workspace usage guide (inside the zip)

The full source files (`docker-compose.yml`, `Dockerfile`, `entrypoint.sh`, `scripts/openclaw.sh`, role configs) live inside [`openclaw-docker.zip`](openclaw-docker.zip).
