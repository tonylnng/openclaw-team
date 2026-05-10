# OpenClaw Ubuntu Docker Stack

Version: see `VERSION` file. Changelog: `CHANGELOG.md`.

Starting in 1.2.0 each role container ships with Node.js 22 LTS and OpenClaw
pre-installed. The gateway runs as `root` inside the container and auto-starts
whenever the container starts — once you've run `openclaw setup` once for that
role. Per-role isolation comes from a dedicated named volume
(`openclaw_config_<role>`) mounted at `/root/.openclaw`, not from a CLI profile.
See `CHANGELOG.md` for the per-role host port mapping, the migration from 1.1.x,
and the full gateway management commands.

This project creates six persistent Ubuntu role containers for an OpenClaw-style multi-agent working environment:

- `openclaw-architect`
- `openclaw-designer`
- `openclaw-developer`
- `openclaw-qc`
- `openclaw-operator`
- `openclaw-pa`

Each container uses the same Ubuntu 24.04 base image, has its own persistent role workspace, and also mounts a shared workspace for collaboration.

## Layout

```text
openclaw-docker/
  docker-compose.yml
  .env.example
  docker/base/
    Dockerfile
    entrypoint.sh
  config/roles/
    architect/
    designer/
    developer/
    qc/
    operator/
    pa/
  bootstrap/
  scripts/
    openclaw.sh
    install-docker-ubuntu.sh
```

## What is included

The common image includes:

- Ubuntu 24.04
- non-root `openclaw` user with passwordless sudo
- Git, curl, jq, vim, nano, htop, tree, rsync, unzip, zip
- Python 3, pip, venv
- Node.js and npm
- OpenJDK 21
- OpenSSH server and client
- common networking/debugging tools

The image intentionally does not install every heavy runtime by default. Add project-specific runtimes, such as .NET SDK, Kubernetes CLIs, OpenShift CLI, n8n CLI tooling, or vendor SDKs, in `docker/base/Dockerfile` when needed.

## Quick start

On your Ubuntu VM:

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
```

First-run setup, once per role. Each call runs **two** interactive OpenClaw
steps under the hood — `openclaw setup` (creates `~/.openclaw/openclaw.json`)
and `openclaw configure` (pick provider, API key, gateway settings) — then
restarts the container so the gateway picks up the config:

```bash
./scripts/openclaw.sh setup pa
./scripts/openclaw.sh setup architect
./scripts/openclaw.sh setup designer
./scripts/openclaw.sh setup developer
./scripts/openclaw.sh setup qc
./scripts/openclaw.sh setup operator

./scripts/openclaw.sh gateway status   # expect 6x UP
```

If you only need to change provider/model later (e.g. swap OpenAI for
Anthropic), use `./scripts/openclaw.sh configure <role>` to rerun just the
configure step.

From this point the gateway in each role auto-starts on every container start
(host reboot, `docker compose down/up`, single-role `restart`). The config is
persisted in the per-role `openclaw_config_<role>` named volume, so you do not
need to re-run `setup` after a rebuild.

If Docker is not installed:

```bash
chmod +x scripts/install-docker-ubuntu.sh
./scripts/install-docker-ubuntu.sh
newgrp docker
```

Then run the quick-start commands again.

If `docker compose` is unavailable on your VM, install the Docker Compose plugin:

```bash
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
```

The helper script also supports legacy `docker-compose` if that is what your VM has installed.

If Ubuntu cannot locate `docker-compose-plugin`, either run the included Docker installer or install legacy Compose:

```bash
./scripts/install-docker-ubuntu.sh
```

```bash
sudo apt-get update
sudo apt-get install -y docker-compose
```

## FAQ and checks

Before building on a new VM, review:

```text
FAQ.md
```

It includes pre-flight checks for Docker, Compose, permissions, ports, disk space, memory, workspace behavior, SSH, backups, and common recovery commands.

## Common commands

```bash
./scripts/openclaw.sh build
./scripts/openclaw.sh up
./scripts/openclaw.sh down
./scripts/openclaw.sh restart
./scripts/openclaw.sh ps
./scripts/openclaw.sh health
./scripts/openclaw.sh logs developer
./scripts/openclaw.sh shell architect
./scripts/openclaw.sh shell designer
./scripts/openclaw.sh shell developer
./scripts/openclaw.sh shell qc
./scripts/openclaw.sh shell operator
./scripts/openclaw.sh shell pa
./scripts/openclaw.sh backup

# OpenClaw gateway management
./scripts/openclaw.sh setup <role>           # first-run: openclaw setup + configure + restart
./scripts/openclaw.sh configure <role>       # rerun just configure (e.g. swap provider)
./scripts/openclaw.sh gateway status          # UP / DOWN / NEEDS_SETUP per role
./scripts/openclaw.sh gateway restart <role>  # restart container (relaunches gateway)
./scripts/openclaw.sh gateway logs <role>     # tail /var/log/openclaw/gateway.log
```

## Workspaces

Inside every container:

- `/workspace/role` is private to that role and backed by a named Docker volume.
- `/workspace/shared` is shared across all roles and backed by a named Docker volume.
- `/opt/openclaw/role` is the read-only role configuration from `config/roles/<role>`.
- `/opt/openclaw/bootstrap` is read-only shared bootstrap material from `bootstrap/`.

Recommended convention:

```text
/workspace/shared/
  inbox/
  decisions/
  specs/
  handoff/
  releases/
```

## SSH access

SSH is disabled by default, but localhost-bound ports are already defined. To enable it:

1. Edit `.env`.
2. Set `ENABLE_SSH=true`.
3. Restart the stack.

```bash
./scripts/openclaw.sh restart
```

Example:

```bash
ssh openclaw@127.0.0.1 -p 2223
```

Important: no password is set for the `openclaw` user. For SSH login, add your public key or set an authentication policy in a secure way before relying on SSH.

To use public-key login, edit:

```text
ssh/authorized_keys
```

Add one public key per line, then restart the stack.

For most local administration, use:

```bash
./scripts/openclaw.sh shell developer
```

## Firewall guidance

The Compose file binds SSH ports to `127.0.0.1`, not `0.0.0.0`, so they are not directly exposed to your LAN or the internet by default.

For a cloud or remote VM:

- Prefer Tailscale, WireGuard, or SSH tunneling for access.
- Avoid opening container SSH ports publicly.
- If you must expose ports, restrict by source IP using UFW or cloud security groups.

## Customizing role behavior

Each role has:

- `config/roles/<role>/README.md`
- `config/roles/<role>/profile.sh`

The README is copied into the role workspace the first time the container starts. The profile script is loaded into `/etc/profile.d/` on startup.

You can add more files under each role folder and mount them read-only into the container at:

```text
/opt/openclaw/role
```

## Adding more tools

Edit `docker/base/Dockerfile`, then rebuild:

```bash
./scripts/openclaw.sh build
./scripts/openclaw.sh restart
```

Examples you may want to add later:

- .NET SDK
- Docker CLI inside containers
- kubectl
- oc
- n8n CLI or Node-based workflow tooling
- OpenClaw-specific gateway binaries
- internal CA certificates

## Backup

Create a timestamped backup of all named volumes:

```bash
./scripts/openclaw.sh backup
```

Backups are written to:

```text
backups/
```

## Restore outline

Stop the stack:

```bash
./scripts/openclaw.sh down
```

Create the volumes again:

```bash
./scripts/openclaw.sh up
./scripts/openclaw.sh down
```

Restore data using a temporary Ubuntu container with the target volumes mounted. Review the archive contents before restoring to avoid overwriting newer work.

## Notes for your OpenClaw workflow

Suggested division of responsibility:

- Architect: turns goals into system design and governance boundaries.
- Designer: turns requirements into user journeys and acceptance-facing UX.
- Developer: implements services, automations, adapters, and CI/CD scripts.
- QC: validates behavior, regression risk, test coverage, and release gates.
- Operator: owns deployment, runbooks, monitoring, backup, and incidents.
- PA: coordinates the work, summarizes decisions, tracks action items, and supports cross-role handoff.

The shared volume gives you a simple synchronization point before introducing heavier orchestration such as n8n, Redis, message queues, or an OpenClaw gateway layer.
