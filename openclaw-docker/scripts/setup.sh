#!/usr/bin/env bash
# setup.sh — first-time setup for the OpenClaw Docker stack.
#
# * Ensures a `.env` file exists (seeded from `.env.example` if missing).
# * Creates per-agent data directories so compose bind mounts succeed.
# * Reports missing prerequisites instead of continuing silently.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

AGENTS=(architect designer developer qc operator pa)

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed or not on PATH." >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
  echo "ERROR: neither 'docker compose' nor 'docker-compose' is available." >&2
  echo "Install the Docker Compose plugin or the legacy docker-compose binary." >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example — edit it to fill in OPENCLAW_API_KEY / OPENCLAW_API_URL if your deployment requires them."
fi

for agent in "${AGENTS[@]}"; do
  mkdir -p "data/${agent}"
  mkdir -p "config/${agent}"
done

echo "Setup complete. Next steps:"
echo "  1. Review .env (defaults use ghcr.io/openclaw/openclaw:latest; set OPENCLAW_API_KEY if required)."
echo "  2. ./scripts/start.sh"
