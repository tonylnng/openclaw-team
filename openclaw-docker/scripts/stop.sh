#!/usr/bin/env bash
# stop.sh — stop the OpenClaw agent stack.
#
# Usage:
#   ./scripts/stop.sh               # stop all agents (containers preserved)
#   ./scripts/stop.sh --down        # stop AND remove containers + network
#   ./scripts/stop.sh architect qc  # stop only specific agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_compose.sh
source "${SCRIPT_DIR}/_compose.sh"

if [[ "${1:-}" == "--down" ]]; then
  shift
  "${COMPOSE[@]}" down "$@"
  exit 0
fi

if [[ $# -eq 0 ]]; then
  "${COMPOSE[@]}" stop
else
  for agent in "$@"; do
    if ! is_valid_agent "${agent}"; then
      echo "ERROR: unknown agent '${agent}'. Valid: ${VALID_AGENTS[*]}" >&2
      exit 1
    fi
  done
  "${COMPOSE[@]}" stop "$@"
fi
