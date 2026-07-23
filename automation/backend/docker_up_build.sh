#!/usr/bin/env bash
# dash Build and start Docker backend stack
# Build and start the Docker backend stack — env from wfrun (.env.local / .env.prod).
#
# Usage (via wfrun):
#   wfrun → automation/backend/docker_up_build.sh
#
# Optional service names (rebuild/start subset only):
#   wfrun → … then pass args, e.g. only API:
#   bash automation/backend/docker_up_build.sh Arcori_api

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${WFRUN_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
DOCKER_DIR="$REPO_ROOT/docker"

require_wfrun() {
  if [[ -z "${WFRUN_MODE:-}" || -z "${WFRUN_ENV_FILE:-}" ]]; then
    echo "❌ Run via wfrun — this script expects exported env (WFRUN_MODE, WFRUN_ENV_FILE)." >&2
    exit 1
  fi
}

require_wfrun

ENV_FILE="$WFRUN_ENV_FILE"

case "$WFRUN_MODE" in
  local)
    COMPOSE_FILE="${COMPOSE_FILE:-$DOCKER_DIR/docker-compose.debug.yml}"
    ;;
  prod)
    COMPOSE_FILE="${COMPOSE_FILE:-$DOCKER_DIR/docker-compose.yml}"
    ;;
  *)
    echo "❌ Unsupported WFRUN_MODE: $WFRUN_MODE (expected local or prod)" >&2
    exit 1
    ;;
esac

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Env file not found: $ENV_FILE" >&2
  exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "❌ Compose file not found: $COMPOSE_FILE" >&2
  exit 1
fi

echo "🐳 wfrun ($WFRUN_MODE): docker compose up --build -d"
echo "   env:     $ENV_FILE"
echo "   compose: $COMPOSE_FILE"
if [[ $# -gt 0 ]]; then
  echo "   services: $*"
fi

cd "$DOCKER_DIR"
exec docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up --build -d "$@"
