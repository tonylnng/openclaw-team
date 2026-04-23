# Deployment Guide

This guide describes a generic deployment flow for the OpenClaw Ubuntu Docker stack.

## Prerequisites

- Ubuntu 22.04 or newer
- Docker Engine
- Docker Compose plugin
- A user account with permission to run Docker
- Sufficient disk space for six persistent role workspaces

For detailed validation commands before deployment, see `FAQ.md`.

## Install Docker

If Docker is not already installed, run:

```bash
chmod +x scripts/install-docker-ubuntu.sh
./scripts/install-docker-ubuntu.sh
newgrp docker
```

## Start the stack

```bash
./scripts/openclaw.sh init
./scripts/openclaw.sh build
./scripts/openclaw.sh up
./scripts/openclaw.sh ps
```

## Compose compatibility

The helper script supports both:

```bash
docker compose
```

and:

```bash
docker-compose
```

If neither is available, install the Compose plugin:

```bash
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
```

If the plugin package is unavailable from your apt sources, install Docker using the included installer:

```bash
chmod +x scripts/install-docker-ubuntu.sh
./scripts/install-docker-ubuntu.sh
newgrp docker
```

Or install legacy Compose:

```bash
sudo apt-get update
sudo apt-get install -y docker-compose
```

## Verify

```bash
./scripts/openclaw.sh health
```

## Access containers

```bash
./scripts/openclaw.sh shell architect
./scripts/openclaw.sh shell designer
./scripts/openclaw.sh shell developer
./scripts/openclaw.sh shell qc
./scripts/openclaw.sh shell operator
./scripts/openclaw.sh shell pa
```

## Stop the stack

```bash
./scripts/openclaw.sh down
```

## Backup

```bash
./scripts/openclaw.sh backup
```
