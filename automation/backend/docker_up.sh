#!/usr/bin/env bash
# dash Start or restart Docker backend stack (no rebuild)
# Start the Docker backend stack without rebuilding images — env from wfrun
# (.env.local / .env.prod). If the engine and target containers are already
# running, restarts those containers instead of a no-op up. Use
# docker_up_build.sh when images need a rebuild.
#
# Optional: WFRUN_MIRROR_GLOBAL_LOG=1 (or dashboard checkbox) spawns
# docker_logs_to_global_log.sh after compose up/restart.
#
# Usage (via wfrun):
#   wfrun → automation/backend/docker_up.sh
#
# Optional service names (start/restart subset only):
#   bash automation/backend/docker_up.sh Arcori_api

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${WFRUN_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
DOCKER_DIR="$REPO_ROOT/docker"

# shellcheck source=docker_up_common.sh
source "$SCRIPT_DIR/docker_up_common.sh"

docker_up_require_wfrun

ENV_FILE="$WFRUN_ENV_FILE"
docker_up_resolve_compose "$DOCKER_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Env file not found: $ENV_FILE" >&2
  exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "❌ Compose file not found: $COMPOSE_FILE" >&2
  exit 1
fi

echo "🐳 wfrun ($WFRUN_MODE): docker_up (up -d or restart if already running)"
echo "   env:     $ENV_FILE"
echo "   compose: $COMPOSE_FILE"
if [[ $# -gt 0 ]]; then
  echo "   services: $*"
fi
if docker_up_env_truthy "${WFRUN_MIRROR_GLOBAL_LOG:-}"; then
  echo "   mirror:  WFRUN_MIRROR_GLOBAL_LOG on → spawn after up/restart"
fi

docker_up_require_engine

cd "$DOCKER_DIR"
docker_up_compose_up_or_restart "$ENV_FILE" "$COMPOSE_FILE" "$@"
docker_up_maybe_spawn_global_log_mirror "$SCRIPT_DIR" "$REPO_ROOT"
