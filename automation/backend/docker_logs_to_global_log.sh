#!/usr/bin/env bash
# dash Tail Docker logs and mirror [dev] to global.log
# Tail Docker backend logs and mirror [dev] lines into repo-root global.log.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${WFRUN_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
DOCKER_DIR="$REPO_ROOT/docker"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env.local}"
COMPOSE_FILE="${COMPOSE_FILE:-$DOCKER_DIR/docker-compose.debug.yml}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Env file not found: $ENV_FILE" >&2
  exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "❌ Compose file not found: $COMPOSE_FILE" >&2
  exit 1
fi

# shellcheck source=../frontend/global_log_filter.sh
source "$SCRIPT_DIR/../frontend/global_log_filter.sh"

echo "📋 Mirroring [dev] lines from Arcori_api + Arcori_dart → $(_global_log_path)" >&2
echo "   (full stream on terminal; Ctrl+C to stop)" >&2

cd "$DOCKER_DIR"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" logs -f Arcori_api Arcori_dart 2>&1 \
  | filter_dev_lines_to_global_log
