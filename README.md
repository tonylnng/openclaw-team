# OpenClaw Team

This repository contains **two separate Docker setups** for running the six OpenClaw agents:

- `openclaw-architect`
- `openclaw-designer`
- `openclaw-developer`
- `openclaw-qc`
- `openclaw-operator`
- `openclaw-pa`

Pick the setup that matches how you want to run OpenClaw.

---

## 📁 Repository layout

```
.
├── openclaw-linux-docker/   # Original: custom Ubuntu image + shared workspaces
└── openclaw-docker/         # New:      OpenClaw Docker image directly, one per agent
```

Each directory is self-contained. Change into whichever you want and follow its `README.md`.

---

## 🐧 `openclaw-linux-docker/` — Ubuntu-based stack with shared workspaces

Builds a **custom Ubuntu base image** and runs each role on top of it. Every agent gets a private workspace plus a shared workspace, with role-specific profile scripts and a bootstrap directory mounted in.

Use this when you want:

- A ready-to-go Ubuntu shell per role (interactive work, scripting, tooling).
- A shared `/workspace/shared` volume for cross-agent collaboration.
- Everything bundled in a zip for air-gapped / offline transfer.
- The helper `scripts/openclaw.sh` for `init / build / up / ps / shell / health / backup`.

Quick start:

```bash
cd openclaw-linux-docker
unzip openclaw-docker.zip
cd openclaw-docker
chmod +x scripts/*.sh docker/base/entrypoint.sh
./scripts/openclaw.sh init
./scripts/openclaw.sh build
./scripts/openclaw.sh up
```

See `openclaw-linux-docker/README.md`, `openclaw-linux-docker/DEPLOYMENT.md`, `openclaw-linux-docker/USAGE.md`, and `openclaw-linux-docker/FAQ.md` for the full guide.

---

## 🐳 `openclaw-docker/` — OpenClaw image directly (one container per agent)

Runs the **OpenClaw Docker image as-is**, one container per agent, with Docker Compose. Each agent has a distinct container name, host port, config folder, and persistent data volume — ready to put behind a reverse proxy.

Use this when you want:

- To run the official (or your own) OpenClaw image without layering a custom base.
- Per-agent host ports (`18001`–`18006` by default) ready for reverse-proxy routing.
- Isolated config (`config/<agent>/agent.yaml`) and state (`data/<agent>/`) per agent.
- A simple `.env` file to swap the image, ports, and shared credentials.

Quick start (Ubuntu VM):

```bash
cd openclaw-docker
./scripts/setup.sh                  # seeds .env from .env.example, creates data/ + config/ dirs
$EDITOR .env                        # defaults are sane; only edit if overriding image/ports/token
docker compose config >/dev/null    # validate compose + .env interpolation
./scripts/start.sh                  # docker compose up -d (pulls ghcr.io/openclaw/openclaw:latest)
./scripts/status.sh                 # confirm all six agents are Up / healthy
```

Key defaults (from the latest `.env.example`):

- `OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest`
- `OPENCLAW_INTERNAL_PORT=18789` (port the image listens on inside each container)
- `OPENCLAW_GATEWAY_TOKEN=` (left blank — first-run onboarding generates it; paste an existing token only if pre-seeding)

> **Note:** the legacy `OPENCLAW_API_KEY` / `OPENCLAW_API_URL` variables have been removed. Use `OPENCLAW_GATEWAY_TOKEN` — it's the only auth secret the stack needs.

See `openclaw-docker/README.md` for the full kick-start, reverse-proxy patterns, and troubleshooting.

---

## 🤔 Which one should I use?

| Need                                              | Use                    |
|---------------------------------------------------|------------------------|
| Interactive Ubuntu shell per role                 | `openclaw-linux-docker` |
| Shared cross-agent workspace                      | `openclaw-linux-docker` |
| Run the upstream OpenClaw Docker image directly   | `openclaw-docker`      |
| One host port per agent for reverse proxy routing | `openclaw-docker`      |
| Minimal config surface (just `.env`)              | `openclaw-docker`      |
| Offline / air-gapped zip distribution             | `openclaw-linux-docker` |

The two setups are independent — you can keep both in the repo and only run the one you need at any given time.

---

## Prerequisites (both setups)

- Linux host (Ubuntu 22.04+ recommended)
- Docker Engine 24+
- Docker Compose v2 (`docker compose ...`) — legacy `docker-compose` also accepted

See each subdirectory's README for details.
