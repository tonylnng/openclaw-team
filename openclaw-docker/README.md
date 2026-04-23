# OpenClaw Docker

A Docker Compose stack that runs six OpenClaw agents using the **OpenClaw Docker image directly** (one container per agent, no custom base image):

| Agent                 | Container name         | Default host port | Role id     |
|-----------------------|------------------------|-------------------|-------------|
| OpenClaw Architect    | `openclaw-architect`   | `18001`           | `architect` |
| OpenClaw Designer     | `openclaw-designer`    | `18002`           | `designer`  |
| OpenClaw Developer    | `openclaw-developer`   | `18003`           | `developer` |
| OpenClaw QC           | `openclaw-qc`          | `18004`           | `qc`        |
| OpenClaw Operator     | `openclaw-operator`    | `18005`           | `operator`  |
| OpenClaw PA           | `openclaw-pa`          | `18006`           | `pa`        |

This setup is different from `../openclaw-linux-docker/`, which builds a custom Ubuntu-based image with shared workspaces. Here, each agent runs an OpenClaw image directly with its own persistent volume, config, and published port — ideal for putting a reverse proxy in front.

---

## Contents

```
openclaw-docker/
├── .env.example              # copy to .env and fill in real values
├── .gitignore
├── docker-compose.yml        # six services: architect, designer, developer, qc, operator, pa
├── config/
│   ├── architect/agent.yaml  # mounted read-only at /opt/openclaw/config
│   ├── designer/agent.yaml
│   ├── developer/agent.yaml
│   ├── qc/agent.yaml
│   ├── operator/agent.yaml
│   └── pa/agent.yaml
├── data/                     # per-agent persistent data (bind mounted)
│   └── .gitkeep
└── scripts/
    ├── setup.sh              # one-time setup (creates .env, data dirs, checks prereqs)
    ├── start.sh              # docker compose up -d  (optionally one or more agents)
    ├── stop.sh               # docker compose stop   (use --down to also remove)
    ├── logs.sh               # docker compose logs -f
    ├── exec.sh               # interactive shell inside an agent
    ├── status.sh             # docker compose ps
    └── _compose.sh           # shared helper (not invoked directly)
```

---

## Prerequisites

- Ubuntu 22.04+ (any recent Linux distro works)
- Docker Engine 24+
- Docker Compose v2 (`docker compose ...`) — legacy `docker-compose` also works
- Outbound network access to the registry that hosts your OpenClaw image

If you don't have Docker installed yet, see `../openclaw-linux-docker/scripts/install-docker-ubuntu.sh` (works for both setups) or follow the official Docker Engine install guide.

Confirm your tooling:

```bash
docker --version
docker compose version   # or: docker-compose --version
```

---

## Quick start

```bash
cd openclaw-docker

# 1. Seed .env and create per-agent data directories.
./scripts/setup.sh

# 2. Edit .env. The image defaults to `ghcr.io/openclaw/openclaw:latest`;
#    at a minimum fill in real credentials if your deployment needs them:
#      OPENCLAW_API_KEY=<real-key>
#      OPENCLAW_API_URL=<real-url>
$EDITOR .env

# 3. Start every agent in the background.
./scripts/start.sh

# 4. Check that all six are Up.
./scripts/status.sh
```

Each agent will be reachable on its own port on the host:

```
http://<host>:18001   # architect
http://<host>:18002   # designer
http://<host>:18003   # developer
http://<host>:18004   # qc
http://<host>:18005   # operator
http://<host>:18006   # pa
```

---

## Configuration

### `.env`

All tunable values live in `.env` (copied from `.env.example`). The most important ones:

| Variable                     | Purpose                                                             |
|------------------------------|---------------------------------------------------------------------|
| `OPENCLAW_IMAGE`             | The OpenClaw Docker image every agent runs. Defaults to `ghcr.io/openclaw/openclaw:latest`. |
| `OPENCLAW_INTERNAL_PORT`     | Port the image listens on inside the container (default `18789`).   |
| `OPENCLAW_API_KEY`           | API key exposed to every agent as `OPENCLAW_API_KEY`.              |
| `OPENCLAW_API_URL`           | API base URL exposed as `OPENCLAW_API_URL`.                        |
| `<AGENT>_HOST_PORT`          | Host port published for each agent.                                 |
| `<AGENT>_CONTAINER_NAME`     | Container name for each agent.                                      |
| `OPENCLAW_DATA_DIR`          | Base host directory for persistent data (default `./data`).         |
| `OPENCLAW_CONFIG_DIR`        | Base host directory for per-agent config (default `./config`).      |
| `OPENCLAW_NETWORK`           | Bridge network name all agents join.                                |
| `OPENCLAW_TZ`                | Timezone inside each container.                                     |

**If your OpenClaw image listens on a port other than `18789`, change `OPENCLAW_INTERNAL_PORT`.** The compose health check also uses this port.

### Recommended `.env` for the six-agent setup

A reasonable starting `.env` after running `./scripts/setup.sh`:

```bash
# Image — official OpenClaw image on GHCR.
OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest
OPENCLAW_PULL_POLICY=always
OPENCLAW_RESTART_POLICY=unless-stopped

# Shared runtime.
OPENCLAW_NETWORK=openclaw-net
OPENCLAW_DATA_DIR=./data
OPENCLAW_CONFIG_DIR=./config
OPENCLAW_TZ=UTC
OPENCLAW_LOG_DRIVER=json-file
OPENCLAW_LOG_MAX_SIZE=10m
OPENCLAW_LOG_MAX_FILE=3

# Credentials — fill in locally, do NOT commit.
OPENCLAW_API_KEY=
OPENCLAW_API_URL=https://api.openclaw.example.com

# Internal port the OpenClaw image listens on.
OPENCLAW_INTERNAL_PORT=18789

# Per-agent containers.
ARCHITECT_CONTAINER_NAME=openclaw-architect
DESIGNER_CONTAINER_NAME=openclaw-designer
DEVELOPER_CONTAINER_NAME=openclaw-developer
QC_CONTAINER_NAME=openclaw-qc
OPERATOR_CONTAINER_NAME=openclaw-operator
PA_CONTAINER_NAME=openclaw-pa

# Per-agent host ports.
ARCHITECT_HOST_PORT=18001
DESIGNER_HOST_PORT=18002
DEVELOPER_HOST_PORT=18003
QC_HOST_PORT=18004
OPERATOR_HOST_PORT=18005
PA_HOST_PORT=18006

# Per-agent role ids.
ARCHITECT_ROLE=architect
DESIGNER_ROLE=designer
DEVELOPER_ROLE=developer
QC_ROLE=qc
OPERATOR_ROLE=operator
PA_ROLE=pa
```

### Per-agent config

Each `config/<agent>/agent.yaml` is mounted read-only at `/opt/openclaw/config/agent.yaml` inside that agent's container. Add image-specific settings there. If your OpenClaw image reads configuration from a different path, update the `volumes:` entry in `docker-compose.yml` accordingly.

### Per-agent data

Each agent has a persistent bind mount at `data/<agent>` → `/var/lib/openclaw`. Survives `docker compose down`. Adjust the container-side path if the OpenClaw image stores state elsewhere.

---

## Usage

### Start / stop

```bash
./scripts/start.sh                    # all six
./scripts/start.sh architect qc       # just two
./scripts/stop.sh                     # stop all (keep containers)
./scripts/stop.sh architect           # stop one
./scripts/stop.sh --down              # stop AND remove containers + network
```

### Logs

```bash
./scripts/logs.sh                     # follow everything
./scripts/logs.sh developer           # follow one
./scripts/logs.sh --no-follow pa      # tail last 200 lines, do not follow
```

### Enter a container

The helper script picks `bash` if present, else `sh`:

```bash
./scripts/exec.sh architect
./scripts/exec.sh developer -- ls /opt/openclaw/config
```

Equivalent raw commands if you don't want the helper:

```bash
docker compose exec architect bash
docker exec -it openclaw-architect bash
```

### Status / health

```bash
./scripts/status.sh
docker compose ps
docker inspect --format '{{.State.Health.Status}}' openclaw-architect
```

### Upgrade the image

```bash
# After bumping OPENCLAW_IMAGE in .env:
docker compose pull
./scripts/start.sh
```

---

## Reverse proxy / routing

Because each agent has a distinct hostname (`openclaw-architect`, `openclaw-designer`, …) on the `openclaw-net` bridge and a distinct host port, you can front them with nginx/Caddy/Traefik in either of two ways:

1. **Same Docker network:** attach the proxy container to `openclaw-net` (`networks: [openclaw-net]` in its compose file using `external: true`) and route upstreams to `http://openclaw-architect:18789`, `http://openclaw-designer:18789`, etc. (or whatever `OPENCLAW_INTERNAL_PORT` is set to).
2. **Host-port routing:** route upstreams to `http://127.0.0.1:18001`, `http://127.0.0.1:18002`, … on the Docker host.

Both patterns work; option 1 keeps the ports off the public host interface.

---

## Troubleshooting

### `OPENCLAW_IMAGE` cannot be pulled
If `docker compose` fails with `pull access denied` or `manifest not found`, the tag in `OPENCLAW_IMAGE` is not reachable. Check you're logged in to `ghcr.io` if the image is private (`docker login ghcr.io`), pin to a known-good tag, or point at a locally-built image, then `./scripts/start.sh` again.

### Port already in use
Change the offending `<AGENT>_HOST_PORT` value in `.env`, then restart:

```bash
./scripts/stop.sh --down
./scripts/start.sh
```

### Container exits immediately / restart loop
```bash
./scripts/logs.sh <agent>
```
Common causes: the image needs extra env vars not yet wired in, the image's internal port isn't `18789` (update `OPENCLAW_INTERNAL_PORT`), or the config file path mounted at `/opt/openclaw/config/agent.yaml` isn't where the image expects it.

### `permission denied` writing to `./data/<agent>`
The container user may not match your host UID. Either run the agents as your UID by adding `user: "${UID}:${GID}"` to each service, or `chown` the data directory to match the UID the image uses.

### `docker compose` not found
Install the plugin:

```bash
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
```

If your distro doesn't ship the plugin, legacy `docker-compose` also works — the helper scripts detect it automatically.

### Verify compose file syntax without starting anything
```bash
docker compose config >/dev/null && echo OK
```

---

## Cleanup

```bash
# Stop + remove containers and the network (keeps data on disk).
./scripts/stop.sh --down

# Nuclear option: also remove all persistent data.
./scripts/stop.sh --down
rm -rf data/*/
```

---

## Security notes

- `.env` is gitignored. Never commit real API keys.
- `.env.example` ships with `OPENCLAW_API_KEY=` blank on purpose — set a real value only in your local `.env`.
- For production, consider managing secrets with Docker secrets or an external manager instead of plain env vars.
