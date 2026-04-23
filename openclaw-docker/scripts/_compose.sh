#!/usr/bin/env bash
# _compose.sh — shared helper. Sourced by the other scripts.
#
# * Exports `COMPOSE` as the command prefix ("docker compose" or
#   "docker-compose") — prefers the modern Compose v2 plugin when
#   available, falls back to the legacy v1 binary.
# * Exports `COMPOSE_PROJECT_NAME=openclaw` so containers land in the
#   same project regardless of which directory the scripts are run from.
#   This replaces the top-level `name:` field that legacy docker-compose
#   does not understand.
# * cds into the repo root so relative paths in docker-compose.yml work.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-openclaw}"

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "ERROR: neither 'docker compose' nor 'docker-compose' is available." >&2
  exit 1
fi

VALID_AGENTS=(architect designer developer qc operator pa)

is_valid_agent() {
  local needle="$1"
  for a in "${VALID_AGENTS[@]}"; do
    if [[ "${a}" == "${needle}" ]]; then
      return 0
    fi
  done
  return 1
}
