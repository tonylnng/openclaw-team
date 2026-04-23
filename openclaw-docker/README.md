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

- Ubuntu 22.04+ VM (any recent Linux distro works)
- Docker Engine 24+
- Docker Compose v2 (`docker compose ...`) — legacy `docker-compose` also works
- `git` to clone this repository
- Outbound network access to `ghcr.io` (or wherever your `OPENCLAW_IMAGE` lives)
- If you plan to reach the agents from another machine, open TCP `18001`–`18006` on the VM firewall (or whichever `<AGENT>_HOST_PORT` values you pick)

If Docker isn't installed yet, either run `../openclaw-linux-docker/scripts/install-docker-ubuntu.sh` (works for both setups) or follow the official Docker Engine install guide. Make sure your user is in the `docker` group so you don't need `sudo`:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

Confirm your tooling:

```bash
docker --version
docker compose version   # or: docker-compose --version
git --version
```

---

## Kick-start (Ubuntu VM, end-to-end)

The path below takes a fresh Ubuntu VM to six running OpenClaw agents. Run every step from the VM shell.

**a. Clone the repo (or checkout this branch if it isn't merged yet):**

```bash
git clone https://github.com/tonylnng/openclaw-team.git
cd openclaw-team
# If you're working off a branch that isn't merged to main:
# git fetch origin fill-openclaw-env-defaults && git checkout fill-openclaw-env-defaults
```

**b. Change into this setup:**

```bash
cd openclaw-docker
```

**c. Run the one-time setup script:**

```bash
./scripts/setup.sh
```

This checks for `docker` + `docker compose`, seeds `.env` from `.env.example` if missing, and creates `data/<agent>/` and `config/<agent>/` directories.

**d. Inspect / edit `.env`:**

```bash
$EDITOR .env
```

The defaults are suitable for a single-VM development deployment. You only need to edit if you're pinning a different image tag, changing host ports, or pre-seeding a token.

**e. Confirm the key defaults:**

```bash
grep -E '^(OPENCLAW_IMAGE|OPENCLAW_INTERNAL_PORT|OPENCLAW_GATEWAY_TOKEN)=' .env
```

Expected values on a fresh `.env`:

```
OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest
OPENCLAW_INTERNAL_PORT=18789
OPENCLAW_GATEWAY_TOKEN=
```

Leave `OPENCLAW_GATEWAY_TOKEN` blank unless you are pre-seeding a token from a previous onboarding run.

**f. Validate the compose file + `.env` interpolation:**

```bash
docker compose config >/dev/null && echo "compose OK"
```

Any unset/mis-quoted variable surfaces here, before you try to start anything.

**g. Pull and start the stack:**

```bash
./scripts/start.sh        # docker compose up -d, pulls image if needed
# or, equivalently:
# docker compose pull && docker compose up -d
```

**h. Check status + logs:**

```bash
./scripts/status.sh               # table of all six agents
./scripts/logs.sh --no-follow     # last 200 lines from every agent
./scripts/logs.sh architect       # follow a single agent
```

**i. Open the dashboards for the six agents:**

| Agent     | URL                     |
|-----------|-------------------------|
| architect | `http://<host>:18001`   |
| designer  | `http://<host>:18002`   |
| developer | `http://<host>:18003`   |
| qc        | `http://<host>:18004`   |
| operator  | `http://<host>:18005`   |
| pa        | `http://<host>:18006`   |

Replace `<host>` with the VM's IP / DNS name. From the VM itself you can use `http://127.0.0.1:<port>`.

**j. Complete onboarding / obtain the gateway token:**

On first boot, each agent's onboarding flow (exposed via its dashboard / Control UI) generates a gateway token and writes it under that agent's `data/` volume. Two options:

- **Let each agent self-onboard.** Open each dashboard, follow the flow, and leave `OPENCLAW_GATEWAY_TOKEN` blank in `.env`.
- **Pre-seed a shared token.** Run onboarding once, copy the generated value into `.env` as `OPENCLAW_GATEWAY_TOKEN=<token>`, then restart: `./scripts/stop.sh && ./scripts/start.sh`.

Treat the token like any other secret — never commit it.

**k. Enter a container for inspection / ad-hoc work:**

```bash
./scripts/exec.sh architect                       # interactive shell
./scripts/exec.sh developer -- ls /opt/openclaw   # one-shot command
```

That's it — six agents running, reachable on `18001`–`18006`, ready for a reverse proxy or direct access.

---

## Configuration

### `.env`

All tunable values live in `.env` (copied from `.env.example`). The most important ones:

| Variable                     | Purpose                                                             |
|------------------------------|---------------------------------------------------------------------|
| `OPENCLAW_IMAGE`             | The OpenClaw Docker image every agent runs. Defaults to `ghcr.io/openclaw/openclaw:latest`. |
| `OPENCLAW_INTERNAL_PORT`     | Port the image listens on inside the container (default `18789`).   |
| `OPENCLAW_GATEWAY_TOKEN`     | Gateway/Control-UI auth token. Generated by onboarding; set locally, never commit. |
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

# Gateway token — generated by onboarding. Set locally, do NOT commit.
OPENCLAW_GATEWAY_TOKEN=

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

1. **Same Docker network:** attach the proxy container to `openclaw-net` (`networks: [openclaw-net]` with `external: true` in its compose file) and route upstreams to the in-network hostnames. This keeps the ports off the public host interface.
2. **Host-port routing:** route upstreams to `http://127.0.0.1:18001`, `http://127.0.0.1:18002`, … on the Docker host.

Recommended subdomain → upstream mapping (swap `example.com` for your domain):

| Public hostname               | Docker-network upstream              | Host-port upstream        |
|-------------------------------|--------------------------------------|---------------------------|
| `architect.openclaw.example.com` | `http://openclaw-architect:18789` | `http://127.0.0.1:18001`  |
| `designer.openclaw.example.com`  | `http://openclaw-designer:18789`  | `http://127.0.0.1:18002`  |
| `developer.openclaw.example.com` | `http://openclaw-developer:18789` | `http://127.0.0.1:18003`  |
| `qc.openclaw.example.com`        | `http://openclaw-qc:18789`        | `http://127.0.0.1:18004`  |
| `operator.openclaw.example.com`  | `http://openclaw-operator:18789`  | `http://127.0.0.1:18005`  |
| `pa.openclaw.example.com`        | `http://openclaw-pa:18789`        | `http://127.0.0.1:18006`  |

The `18789` upstream port is `OPENCLAW_INTERNAL_PORT`; if you change it in `.env`, update these upstreams to match.

For production deployments, terminate TLS at the proxy and bind the host ports to `127.0.0.1` only (`127.0.0.1:18001:18789` in `docker-compose.yml`) so nothing is publicly reachable except the proxy.

---

## Troubleshooting

### `pull access denied for your-openclaw-image`
An older version of `.env.example` shipped with a placeholder value
(`OPENCLAW_IMAGE=your-openclaw-image:latest`) that is not a real image.
If your local `.env` was created from that template, `./scripts/start.sh`
fails with:

```
pull access denied for your-openclaw-image, repository does not exist or may require 'docker login'
```

`./scripts/setup.sh` protects local secrets by never overwriting an
existing `.env`, so rerunning setup won't swap in the new default on its
own — but current `setup.sh` performs a targeted migration that replaces
the exact old placeholder with `ghcr.io/openclaw/openclaw:latest` and
leaves every other value untouched:

```bash
./scripts/setup.sh
./scripts/start.sh
```

If you'd rather fix `.env` by hand, the one-liner is:

```bash
sed -i 's|^OPENCLAW_IMAGE=.*|OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest|' .env
./scripts/start.sh
```

### `OPENCLAW_IMAGE` cannot be pulled
If `docker compose` fails with `pull access denied` or `manifest not found` for any other image tag, the tag in `OPENCLAW_IMAGE` is not reachable. Check you're logged in to `ghcr.io` if the image is private (`docker login ghcr.io`), pin to a known-good tag, or point at a locally-built image, then `./scripts/start.sh` again.

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

### Container stays `unhealthy`
The healthcheck does a TCP probe against `OPENCLAW_INTERNAL_PORT` inside the container. If the image listens on a different port, update `OPENCLAW_INTERNAL_PORT` in `.env` and restart. Quick inspection:

```bash
docker inspect --format '{{json .State.Health}}' openclaw-architect | jq
```

### Gateway token / Control-UI rejects requests
`OPENCLAW_GATEWAY_TOKEN` must match what the agent's onboarding produced (or the token you pasted in before first start). If you rotated the token, restart the affected agent so the new value is picked up from `.env`:

```bash
./scripts/stop.sh architect
./scripts/start.sh architect
```

### Custom image listens on a non-default port
Set `OPENCLAW_INTERNAL_PORT` in `.env` to the port your image actually binds to. The compose file plumbs that value into both the port publish and the healthcheck, so you only change it in one place.

### `permission denied` writing to `./data/<agent>`
The container user may not match your host UID. Either run the agents as your UID by adding `user: "${UID}:${GID}"` to each service, or `chown` the data directory to match the UID the image uses:

```bash
sudo chown -R 1000:1000 data/
```

### `Compose file is invalid` / `pull_policy value 'missing' is not one of …` / `'name' does not match`
These errors mean you are running an older Compose schema (typically the
legacy `docker-compose` v1 binary, or an outdated Compose v2 that does
not accept `pull_policy: missing`). The fix is already on `main`:

1. Pull the latest commit (the top-level `name:` and service-level
   `pull_policy:` have been removed from `docker-compose.yml`).
2. Migrate any existing `.env` that still has the old value:
   ```bash
   # Re-run setup; it auto-migrates OPENCLAW_PULL_POLICY=missing → always.
   ./scripts/setup.sh
   # Or do it manually:
   sed -i -E 's/^OPENCLAW_PULL_POLICY=(missing|if_not_present)\s*$/OPENCLAW_PULL_POLICY=always/' .env
   ```
3. Restart the stack:
   ```bash
   ./scripts/start.sh
   ```

Pull behaviour is now driven by `scripts/start.sh` (which calls
`docker compose pull` when `OPENCLAW_PULL_POLICY=always`), so the compose
file stays portable across Compose v2 and legacy docker-compose v1.

Upgrade tip: if you're on Ubuntu, the modern plugin is one command away
(see below) and fixes any `docker compose` syntax gaps in one shot.

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

- `.env` is gitignored — never commit it, especially once it holds a real gateway token. Check with `git status` before every commit.
- `.env.example` ships with `OPENCLAW_GATEWAY_TOKEN=` blank on purpose; onboarding generates the value, or you can paste an existing token into your local `.env`.
- Treat the gateway token like any other credential: rotate it if it leaks, distribute it through a secret manager, and keep it out of shell history (`HISTCONTROL=ignorespace` + leading space, or just edit `.env` with an editor).
- By default the agents bind on all host interfaces (`0.0.0.0`). On any VM reachable from the internet, either:
  - bind the published ports to `127.0.0.1` only (e.g. `"127.0.0.1:18001:18789"` in `docker-compose.yml`) and front them with a reverse proxy that enforces TLS + auth, or
  - restrict inbound traffic to `18001`–`18006` at the firewall / security group level.
- Put nginx / Caddy / Traefik in front for TLS termination, request logging, and auth — don't expose the raw dashboards publicly.
- Limit who can `docker exec` into the containers. Anyone with shell access to the host has effective root inside every agent.
- For production, migrate secrets out of `.env` and into Docker secrets / an external secret manager; `environment:` values are visible to anything that can query the Docker API.
