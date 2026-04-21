# OpenClaw Team Docker Stack

This repository provides a generic Docker Compose package for running six Ubuntu-based OpenClaw role containers:

- `openclaw-architect`
- `openclaw-designer`
- `openclaw-developer`
- `openclaw-qc`
- `openclaw-operator`
- `openclaw-pa`

The downloadable package is included as:

```text
openclaw-docker.zip
```

## Role model

Each role container has:

- A private persistent workspace at `/workspace/role`
- A shared collaboration workspace at `/workspace/shared`
- A role configuration mounted at `/opt/openclaw/role`
- Shared bootstrap assets mounted at `/opt/openclaw/bootstrap`

## Roles

| Container | Purpose |
|---|---|
| `openclaw-architect` | Architecture, requirements decomposition, governance |
| `openclaw-designer` | UX flows, interface specifications, product experience |
| `openclaw-developer` | Implementation, integration, build automation |
| `openclaw-qc` | Test planning, validation, release gates |
| `openclaw-operator` | Deployment, monitoring, operations, incident response |
| `openclaw-pa` | Personal assistant, coordination, summaries, task tracking |

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
```

If Docker is not installed:

```bash
chmod +x scripts/install-docker-ubuntu.sh
./scripts/install-docker-ubuntu.sh
newgrp docker
```

If `docker compose` is unavailable on the VM:

```bash
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
```

## Documentation

- `DEPLOYMENT.md`: generic deployment instructions
- `USAGE.md`: role and workspace usage guide

The full source files are inside the zip package.
