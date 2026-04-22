# FAQ and Pre-flight Checks

This document lists common questions, setup checks, and troubleshooting steps for the OpenClaw Ubuntu Docker stack.

## Pre-flight checks

Run these commands before building the stack.

### 1. Check Ubuntu version

```bash
lsb_release -a
```

Recommended: Ubuntu 22.04 or newer.

### 2. Check Docker Engine

```bash
docker --version
docker info
```

If Docker is missing:

```bash
chmod +x scripts/install-docker-ubuntu.sh
./scripts/install-docker-ubuntu.sh
newgrp docker
```

### 3. Check Docker Compose

```bash
docker compose version || docker-compose version
```

The helper script supports both `docker compose` and `docker-compose`.

If neither command works:

```bash
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
```

If `docker-compose-plugin` cannot be located, your Ubuntu apt sources may not include Docker's official repository. You can either use the legacy package:

```bash
sudo apt-get update
sudo apt-get install -y docker-compose
```

or install Docker Engine and the Compose plugin from Docker's official repository:

```bash
chmod +x scripts/install-docker-ubuntu.sh
./scripts/install-docker-ubuntu.sh
newgrp docker
```

### 4. Check Docker permissions

```bash
groups
docker ps
```

If `docker ps` returns a permission error:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

If the issue remains, log out and log in again.

The helper script also performs this pre-flight check before Docker operations. If the current user cannot access the Docker daemon, it prints the recommended `usermod` and `newgrp` commands instead of showing a long Python traceback from legacy `docker-compose`.

### 5. Check disk space

```bash
df -h
docker system df
```

The stack uses one shared named volume and six private role volumes. Keep enough disk space for source code, build artifacts, logs, and backups.

### 6. Check memory

```bash
free -h
```

The containers are lightweight by default, but development workloads, Java builds, Node builds, and AI-agent tooling may require more memory.

### 7. Check ports

SSH ports are bound to localhost only:

```text
127.0.0.1:2221 architect
127.0.0.1:2222 designer
127.0.0.1:2223 developer
127.0.0.1:2224 qc
127.0.0.1:2225 operator
127.0.0.1:2226 pa
```

Check whether a port is already used:

```bash
ss -ltnp | grep -E '2221|2222|2223|2224|2225|2226' || true
```

Change ports in `.env` if needed.

### 8. Check project files

```bash
test -f docker-compose.yml
test -f .env.example
test -x scripts/openclaw.sh
test -x docker/base/entrypoint.sh
```

If `.env` does not exist:

```bash
./scripts/openclaw.sh init
```

## Build and run checks

### Build image

```bash
./scripts/openclaw.sh build
```

### Start containers

```bash
./scripts/openclaw.sh up
```

### Check status

```bash
./scripts/openclaw.sh ps
```

### Run health check

```bash
./scripts/openclaw.sh health
```

### Open a shell

```bash
./scripts/openclaw.sh shell developer
```

## FAQ

### Does the shared volume mean all roles can access each other files?

All roles can access files placed in:

```text
/workspace/shared
```

Each role also has a private workspace:

```text
/workspace/role
```

Private role workspaces are separate by default. A role cannot access another role's private workspace unless the Compose file is changed to mount those volumes.

### Where should work-in-progress files go?

Use:

```text
/workspace/role
```

for private draft work.

Use:

```text
/workspace/shared
```

for handoff files, specifications, decisions, release notes, and shared artifacts.

### How do I enter a container?

Use:

```bash
./scripts/openclaw.sh shell architect
./scripts/openclaw.sh shell designer
./scripts/openclaw.sh shell developer
./scripts/openclaw.sh shell qc
./scripts/openclaw.sh shell operator
./scripts/openclaw.sh shell pa
```

### How do I see logs?

All logs:

```bash
./scripts/openclaw.sh logs
```

One service:

```bash
./scripts/openclaw.sh logs developer
```

### Why did I get `unknown flag: --project-directory`?

This usually means the Docker command on the VM does not support the newer Compose v2 flag used by some scripts.

The current helper script avoids that flag and supports both:

```bash
docker compose
```

and:

```bash
docker-compose
```

Pull the latest repository version or download the latest zip package.

### Why does `docker compose` not work?

The Docker Compose plugin may be missing. Install it:

```bash
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
```

Then check:

```bash
docker compose version
```

If Ubuntu reports `Unable to locate package docker-compose-plugin`, install Docker using the included installer:

```bash
chmod +x scripts/install-docker-ubuntu.sh
./scripts/install-docker-ubuntu.sh
newgrp docker
```

Or install the legacy Compose package:

```bash
sudo apt-get update
sudo apt-get install -y docker-compose
```

### Why did I get `name does not match any of the regexes: '^x-'`?

This happens when legacy `docker-compose` reads a Compose file containing the newer top-level `name:` field.

The current package removes that field and sets the project name through the helper script instead:

```bash
COMPOSE_PROJECT_NAME=openclaw
```

Pull the latest repository version or download the latest zip package, then retry:

```bash
./scripts/openclaw.sh build
```

### Why does `docker ps` return permission denied?

Your user may not be in the `docker` group.

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

If it still fails, log out and log back in.

### Why does SSH not work?

SSH is disabled by default.

To enable it:

1. Edit `.env`.
2. Set `ENABLE_SSH=true`.
3. Add your public key to `ssh/authorized_keys`.
4. Restart the stack.

```bash
./scripts/openclaw.sh restart
```

For most local use, prefer:

```bash
./scripts/openclaw.sh shell developer
```

### Are the SSH ports public?

No. The Compose file binds SSH ports to `127.0.0.1` by default.

This means they are available only from the VM itself unless you use SSH tunneling, Tailscale, WireGuard, or another secure access layer.

### How do I change the timezone?

Edit `.env`:

```text
OPENCLAW_TZ=Asia/Hong_Kong
```

Then rebuild or restart as needed:

```bash
./scripts/openclaw.sh build
./scripts/openclaw.sh restart
```

### How do I backup the workspaces?

Run:

```bash
./scripts/openclaw.sh backup
```

Backups are written to:

```text
backups/
```

### How do I reset the stack?

Stop containers:

```bash
./scripts/openclaw.sh down
```

Remove containers and network only:

```bash
docker compose down
```

Remove containers, network, and volumes:

```bash
docker compose down -v
```

Warning: `down -v` deletes workspace volumes.

### How do I add more tools?

Edit:

```text
docker/base/Dockerfile
```

Then rebuild:

```bash
./scripts/openclaw.sh build
./scripts/openclaw.sh restart
```

### Why did the build fail with `groupadd: GID '1000' already exists`?

Some Ubuntu base images already contain a group or user with UID/GID `1000`.

The current Dockerfile handles this by reusing and renaming the existing UID/GID entry to `openclaw` where possible.

Pull the latest repository version or download the latest zip package, then rebuild:

```bash
./scripts/openclaw.sh build
```

### Why did the build fail with `npm ERR! code EBADENGINE`?

This happens when `npm@latest` requires a newer Node.js version than the apt-provided Node.js package.

The current Dockerfile avoids upgrading npm during the base-image build and uses Ubuntu's packaged Node.js/npm pair for compatibility.

Pull the latest repository version or download the latest zip package, then rebuild:

```bash
./scripts/openclaw.sh build
```

If a project needs a newer Node.js runtime, install it intentionally using a NodeSource repository, `nvm`, or a dedicated Node base image layer instead of upgrading npm blindly.

If you need a different UID/GID, edit `.env`:

```text
OPENCLAW_UID=1001
OPENCLAW_GID=1001
```

Then rebuild:

```bash
./scripts/openclaw.sh build
```

### How do I check what volumes exist?

```bash
docker volume ls | grep openclaw
```

### How do I inspect a volume?

Example:

```bash
docker run --rm -it \
  -v openclaw_openclaw_shared:/data \
  ubuntu:24.04 \
  bash
```

### What should I check before exposing anything externally?

Check:

- SSH is still bound to `127.0.0.1` unless intentionally changed.
- UFW or cloud firewall rules are restrictive.
- Public keys are used instead of passwords.
- Sensitive files are not placed in shared folders unless needed.
- Backups are protected.
- `.env` does not contain secrets before committing changes.

## Common recovery commands

Restart all containers:

```bash
./scripts/openclaw.sh restart
```

Rebuild cleanly:

```bash
./scripts/openclaw.sh down
./scripts/openclaw.sh build
./scripts/openclaw.sh up
```

Clean unused Docker resources:

```bash
docker system prune
```

Warning: review Docker's prompt before confirming prune operations.
