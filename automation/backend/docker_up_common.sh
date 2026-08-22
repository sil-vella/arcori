# dash Shared helpers for docker compose up scripts
# Sourced by docker_up.sh / docker_up_build.sh — not a standalone wfrun runner.

docker_up_require_wfrun() {
  if [[ -z "${WFRUN_MODE:-}" || -z "${WFRUN_ENV_FILE:-}" ]]; then
    echo "❌ Run via wfrun — this script expects exported env (WFRUN_MODE, WFRUN_ENV_FILE)." >&2
    exit 1
  fi
}

# Sets COMPOSE_FILE from WFRUN_MODE (unless already set).
docker_up_resolve_compose() {
  local docker_dir="$1"
  case "$WFRUN_MODE" in
    local)
      COMPOSE_FILE="${COMPOSE_FILE:-$docker_dir/docker-compose.debug.yml}"
      ;;
    prod)
      COMPOSE_FILE="${COMPOSE_FILE:-$docker_dir/docker-compose.yml}"
      ;;
    *)
      echo "❌ Unsupported WFRUN_MODE: $WFRUN_MODE (expected local or prod)" >&2
      exit 1
      ;;
  esac
}

docker_up_env_truthy() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

# Exit unless the Docker daemon answers (5s timeout when python3 is available).
docker_up_require_engine() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "❌ docker CLI not found on PATH" >&2
    exit 1
  fi
  if command -v python3 >/dev/null 2>&1; then
    if python3 - <<'PY'
import subprocess
import sys

try:
    proc = subprocess.run(["docker", "info"], capture_output=True, timeout=5)
    sys.exit(0 if proc.returncode == 0 else 1)
except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
    sys.exit(1)
PY
    then
      return 0
    fi
  elif docker info >/dev/null 2>&1; then
    return 0
  fi
  echo "❌ Docker is not running. Start Docker Desktop manually, then re-run." >&2
  exit 1
}

# True when every requested service (or any project service if none named) is running.
docker_up_compose_targets_running() {
  local env_file="$1"
  local compose_file="$2"
  shift 2
  local running=""
  local svc=""

  running="$(
    docker compose --env-file "$env_file" -f "$compose_file" \
      ps --status running --services 2>/dev/null || true
  )"
  if [[ -z "$running" ]]; then
    return 1
  fi

  if [[ $# -eq 0 ]]; then
    return 0
  fi

  for svc in "$@"; do
    if ! printf '%s\n' "$running" | grep -qx -- "$svc"; then
      return 1
    fi
  done
  return 0
}

# If target containers are already running → restart; otherwise up -d.
# Args after compose paths are optional service names (same as compose).
docker_up_compose_up_or_restart() {
  local env_file="$1"
  local compose_file="$2"
  shift 2

  if docker_up_compose_targets_running "$env_file" "$compose_file" "$@"; then
    echo "🐳 stack already running — docker compose restart" >&2
    if [[ $# -gt 0 ]]; then
      echo "   services: $*" >&2
    fi
    docker compose --env-file "$env_file" -f "$compose_file" restart "$@"
  else
    echo "🐳 docker compose up -d" >&2
    if [[ $# -gt 0 ]]; then
      echo "   services: $*" >&2
    fi
    docker compose --env-file "$env_file" -f "$compose_file" up -d "$@"
  fi
}

# After compose up: optionally spawn host-side [dev] → global.log mirror.
# Gated by WFRUN_MIRROR_GLOBAL_LOG (1/true/yes/on). Skips if already running.
docker_up_maybe_spawn_global_log_mirror() {
  local script_dir="$1"
  local repo_root="$2"
  local mirror_script pid_file mirror_log

  if ! docker_up_env_truthy "${WFRUN_MIRROR_GLOBAL_LOG:-}"; then
    return 0
  fi

  mirror_script="$script_dir/docker_logs_to_global_log.sh"
  if [[ ! -x "$mirror_script" && ! -f "$mirror_script" ]]; then
    echo "⚠️  Mirror script missing: $mirror_script" >&2
    return 0
  fi

  # Already running? (bracket trick avoids matching this pgrep line)
  if pgrep -f '[d]ocker_logs_to_global_log\.sh' >/dev/null 2>&1; then
    echo "📋 global.log mirror already running — not spawning another" >&2
    return 0
  fi

  mkdir -p "$repo_root/.dashboard_logs"
  mirror_log="$repo_root/.dashboard_logs/docker_logs_mirror.log"
  pid_file="$repo_root/.dashboard_logs/docker_logs_mirror.pid"

  # New session so Stop on the up-script PTY does not kill the mirror.
  # Prefer setsid (Linux); fall back to Python start_new_session (macOS).
  local mirror_pid=""
  if command -v setsid >/dev/null 2>&1; then
    setsid bash "$mirror_script" </dev/null >>"$mirror_log" 2>&1 &
    mirror_pid=$!
  else
    mirror_pid="$(
      python3 - "$mirror_script" "$mirror_log" <<'PY'
import subprocess
import sys

script, log_path = sys.argv[1], sys.argv[2]
with open(log_path, "a", encoding="utf-8") as logf:
    proc = subprocess.Popen(
        ["bash", script],
        stdin=subprocess.DEVNULL,
        stdout=logf,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
print(proc.pid)
PY
    )"
  fi

  if [[ -z "$mirror_pid" ]]; then
    echo "⚠️  Failed to spawn global.log mirror" >&2
    return 0
  fi

  printf '%s\n' "$mirror_pid" >"$pid_file"
  echo "📋 Spawned global.log mirror (pid $mirror_pid) → $mirror_log" >&2
  echo "   (tail -f global.log for Flutter + backend [dev])" >&2
}
