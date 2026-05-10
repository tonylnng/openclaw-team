# OpenClaw Team

Docker stack for running six OpenClaw agents on a single Ubuntu host. Each role gets a persistent container, its own workspace and gateway, plus a shared workspace for cross-role collaboration.

| Role                   | Container                | Gateway port (host) | Purpose |
|------------------------|--------------------------|---------------------|---------|
| OpenClaw Architect     | `openclaw-architect`     | `127.0.0.1:18791`   | Architecture, requirements, governance |
| OpenClaw Designer      | `openclaw-designer`      | `127.0.0.1:18792`   | UX flows, UI specs, prototypes |
| OpenClaw Developer     | `openclaw-developer`     | `127.0.0.1:18793`   | Implementation, integration, build automation |
| OpenClaw QC            | `openclaw-qc`            | `127.0.0.1:18794`   | Test planning, validation, release gates |
| OpenClaw Operator      | `openclaw-operator`      | `127.0.0.1:18795`   | Deployment, monitoring, incident response |
| OpenClaw PA            | `openclaw-pa`            | `127.0.0.1:18796`   | Coordination, summaries, task tracking |

The active stack lives in [`openclaw-linux-docker/`](openclaw-linux-docker/). It builds a custom Ubuntu 24.04 base image with Node.js 22 LTS and the OpenClaw CLI pre-installed, runs each role under its own per-role config volume, and auto-starts the gateway whenever the container starts.

---

## Quick start

On an Ubuntu host with Docker installed:

```bash
git clone https://github.com/tonylnng/openclaw-team.git
cd openclaw-team/openclaw-linux-docker
unzip openclaw-docker.zip -d openclaw-docker
cd openclaw-docker
chmod +x scripts/*.sh docker/base/entrypoint.sh

./scripts/openclaw.sh init
./scripts/openclaw.sh build
./scripts/openclaw.sh up

# First-run setup, once per role (interactive: openclaw setup + configure + restart)
./scripts/openclaw.sh setup pa
./scripts/openclaw.sh setup architect
./scripts/openclaw.sh setup designer
./scripts/openclaw.sh setup developer
./scripts/openclaw.sh setup qc
./scripts/openclaw.sh setup operator

./scripts/openclaw.sh gateway status   # expect 6x UP
```

Once setup is complete the per-role gateway auto-starts on every container start (host reboot, `docker compose down/up`, single-role `restart`). Config persists in the per-role `openclaw_config_<role>` named volume, so a rebuild does not require re-running setup.

If Docker is not installed yet:

```bash
chmod +x scripts/install-docker-ubuntu.sh
./scripts/install-docker-ubuntu.sh
newgrp docker
```

---

## Repository layout

```
.
├── README.md                  # this file
└── openclaw-linux-docker/
    ├── README.md              # detailed user guide
    ├── CHANGELOG.md           # full release history (currently 1.2.1)
    ├── DEPLOYMENT.md          # deployment notes
    ├── FAQ.md                 # pre-flight checks and recovery
    ├── USAGE.md               # day-to-day usage
    ├── VERSION
    └── openclaw-docker.zip    # bundled, self-contained stack (extracts to ./openclaw-docker/)
```

For full documentation see:

- [`openclaw-linux-docker/README.md`](openclaw-linux-docker/README.md) — architecture, commands, customization
- [`openclaw-linux-docker/CHANGELOG.md`](openclaw-linux-docker/CHANGELOG.md) — release notes and migration guides
- [`openclaw-linux-docker/DEPLOYMENT.md`](openclaw-linux-docker/DEPLOYMENT.md) — deployment patterns
- [`openclaw-linux-docker/FAQ.md`](openclaw-linux-docker/FAQ.md) — troubleshooting and recovery
- [`openclaw-linux-docker/USAGE.md`](openclaw-linux-docker/USAGE.md) — operating the stack day-to-day

---

## Prerequisites

- Linux host (Ubuntu 22.04+ recommended; tested on 24.04)
- Docker Engine 24+
- Docker Compose v2 (`docker compose ...`); legacy `docker-compose` is also accepted
- ~4 GB free disk for image build, plus space for per-role workspaces

The stack binds all SSH and gateway ports to `127.0.0.1` only — no LAN exposure by default. For remote access prefer Tailscale, WireGuard, or SSH tunneling.
