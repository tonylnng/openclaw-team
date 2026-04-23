#!/usr/bin/env bash
# start.sh — bring the OpenClaw agent stack up in detached mode.
#
# Usage:
#   ./scripts/start.sh              # all agents
#   ./scripts/start.sh architect qc # only specific agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_compose.sh
source "${SCRIPT_DIR}/_compose.sh"

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
