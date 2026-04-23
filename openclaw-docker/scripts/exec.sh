#!/usr/bin/env bash
# exec.sh — open an interactive shell inside an agent container, or run a
# command inside it.
#
# Usage:
#   ./scripts/exec.sh architect                  # interactive shell
#   ./scripts/exec.sh architect -- ls /opt       # run a specific command

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_compose.sh
source "${SCRIPT_DIR}/_compose.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <agent> [-- command...]" >&2
  echo "Valid agents: ${VALID_AGENTS[*]}" >&2
  exit 1
fi

agent="$1"
shift

if ! is_valid_agent "${agent}"; then
  echo "ERROR: unknown agent '${agent}'. Valid: ${VALID_AGENTS[*]}" >&2
  exit 1
fi

if [[ "${1:-}" == "--" ]]; then
  shift
fi

if [[ $# -eq 0 ]]; then
  # Try bash first, fall back to sh if the image does not ship bash.
  "${COMPOSE[@]}" exec "${agent}" sh -c 'command -v bash >/dev/null 2>&1 && exec bash || exec sh'
else
  "${COMPOSE[@]}" exec "${agent}" "$@"
fi
