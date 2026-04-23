#!/usr/bin/env bash
# logs.sh — tail logs for one or all agents.
#
# Usage:
#   ./scripts/logs.sh                    # follow all agents
#   ./scripts/logs.sh architect          # follow one agent
#   ./scripts/logs.sh --no-follow pa     # print without following

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_compose.sh
source "${SCRIPT_DIR}/_compose.sh"

follow="--follow"
if [[ "${1:-}" == "--no-follow" ]]; then
  follow=""
  shift
fi

if [[ $# -eq 0 ]]; then
  "${COMPOSE[@]}" logs --tail=200 ${follow}
else
  for agent in "$@"; do
    if ! is_valid_agent "${agent}"; then
      echo "ERROR: unknown agent '${agent}'. Valid: ${VALID_AGENTS[*]}" >&2
      exit 1
    fi
  done
  "${COMPOSE[@]}" logs --tail=200 ${follow} "$@"
fi
