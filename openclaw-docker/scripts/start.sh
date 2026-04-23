#!/usr/bin/env bash
# start.sh — bring the OpenClaw agent stack up in detached mode.
#
# Usage:
#   ./scripts/start.sh              # all agents
#   ./scripts/start.sh architect qc # only specific agents
#
# Honours `OPENCLAW_PULL_POLICY` from `.env` (always | never). Pulling
# happens here in the script, not in the compose file, so the behaviour
# is portable across Compose v2 and legacy docker-compose v1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_compose.sh
source "${SCRIPT_DIR}/_compose.sh"

# Load .env if present so OPENCLAW_PULL_POLICY is available here.
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

PULL_POLICY="${OPENCLAW_PULL_POLICY:-always}"
case "${PULL_POLICY}" in
  always)
    if [[ $# -eq 0 ]]; then
      "${COMPOSE[@]}" pull
    else
      "${COMPOSE[@]}" pull "$@"
    fi
    ;;
  never|if_not_present|missing)
    # `if_not_present` / `missing` map to "let compose up handle it".
    ;;
  *)
    echo "WARN: unknown OPENCLAW_PULL_POLICY='${PULL_POLICY}' — skipping pull." >&2
    ;;
esac

if [[ $# -eq 0 ]]; then
  "${COMPOSE[@]}" up -d
else
  for agent in "$@"; do
    if ! is_valid_agent "${agent}"; then
      echo "ERROR: unknown agent '${agent}'. Valid: ${VALID_AGENTS[*]}" >&2
      exit 1
    fi
  done
  "${COMPOSE[@]}" up -d "$@"
fi

"${COMPOSE[@]}" ps
