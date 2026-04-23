#!/usr/bin/env bash
# status.sh — quick view of container state, ports, and health.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_compose.sh
source "${SCRIPT_DIR}/_compose.sh"

"${COMPOSE[@]}" ps
