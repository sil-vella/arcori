#!/usr/bin/env bash
# dash Deploy marketing auto-post scripts (+ optional token sync) to rop01
# Requires: SSH as rop01_user (public IP or VPN). Uses sudo on remote for /opt/marketing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MARKETING="$ROOT/automation/marketing"
HOST="${ROP01_SSH_HOST:-rop01_user@65.181.125.135}"
IDENTITY="${ROP01_SSH_IDENTITY:-$HOME/.ssh/rop01_key}"
ENV_LOCAL="${ROP01_ENV_SOURCE:-$ROOT/.env.local}"
# Sync YT + FB tokens from ENV_LOCAL → /opt/marketing/env/.env (ROP01_UPDATE_YT_TOKEN kept for compat)
UPDATE_TOKENS="${ROP01_UPDATE_TOKENS:-${ROP01_UPDATE_YT_TOKEN:-1}}"

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=25 -i "$IDENTITY" -o IdentitiesOnly=yes)

FILES=(
  cron_social_auto_post.py
  ensure_platform_tokens.py
  facebook_publish_post.py
  youtube_publish_video.py
  tiktok_publish_video.py
  publish_common.py
  token_renewal.py
)

echo "Host: $HOST"
echo "Source scripts: $MARKETING"
ssh "${SSH_OPTS[@]}" "$HOST" 'echo OK; whoami; hostname'

tmpdir="/tmp/marketing_sync_$$"
ssh "${SSH_OPTS[@]}" "$HOST" "rm -rf /tmp/marketing_sync && mkdir -p /tmp/marketing_sync"

scp_args=()
for f in "${FILES[@]}"; do
  scp_args+=("$MARKETING/$f")
done
scp "${SSH_OPTS[@]}" "${scp_args[@]}" "$HOST:/tmp/marketing_sync/"

ssh "${SSH_OPTS[@]}" "$HOST" 'sudo bash -s' <<'REMOTE'
set -euo pipefail
install -d -o root -g root -m 755 /opt/marketing/scripts
for f in cron_social_auto_post.py ensure_platform_tokens.py facebook_publish_post.py youtube_publish_video.py tiktok_publish_video.py publish_common.py token_renewal.py; do
  install -o root -g root -m 755 "/tmp/marketing_sync/$f" "/opt/marketing/scripts/$f"
  echo "installed $f ($(wc -c < /opt/marketing/scripts/$f) bytes)"
done
cd /opt/marketing/scripts
python3 -c "import token_renewal, publish_common, ensure_platform_tokens, facebook_publish_post, youtube_publish_video, tiktok_publish_video; print('imports_ok')"
REMOTE

if [[ "$UPDATE_TOKENS" == "1" ]]; then
  if [[ ! -f "$ENV_LOCAL" ]]; then
    echo "❌ Missing env source: $ENV_LOCAL" >&2
    exit 1
  fi
  SYNC_FILE="$(mktemp /tmp/rop_marketing_env_sync.XXXXXX)"
  chmod 600 "$SYNC_FILE"
  python3 - <<PY
from pathlib import Path
import sys

path = Path(r"""$ENV_LOCAL""")
sync_keys = [
    "YOUTUBE_REFRESH_TOKEN",
    "FACEBOOK_PAGE_ACCESS_TOKEN",
    "FACEBOOK_USER_ACCESS_TOKEN",
]
required = {"YOUTUBE_REFRESH_TOKEN", "FACEBOOK_PAGE_ACCESS_TOKEN"}
vals: dict[str, str] = {}
for raw in path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, _, val = line.partition("=")
    key = key.strip()
    val = val.strip().strip('"').strip("'")
    if key in sync_keys and val:
        vals[key] = val
missing = sorted(required - set(vals))
if missing:
    raise SystemExit(f"missing required keys in source env: {', '.join(missing)}")
out = Path(r"""$SYNC_FILE""")
out.write_text("\n".join(f"{k}={v}" for k, v in vals.items()) + "\n", encoding="utf-8")
for k, v in vals.items():
    print(f"  {k}: len={len(v)}")
if "FACEBOOK_USER_ACCESS_TOKEN" not in vals:
    print("  WARN FACEBOOK_USER_ACCESS_TOKEN missing — FB auto-extend may fail after Page token expiry")
PY
  echo "Updating remote marketing tokens from $ENV_LOCAL…"
  scp "${SSH_OPTS[@]}" "$SYNC_FILE" "$HOST:/tmp/marketing_env_sync"
  rm -f "$SYNC_FILE"
  ssh "${SSH_OPTS[@]}" "$HOST" 'sudo bash -s' <<'REMOTE'
set -euo pipefail
ENVF=/opt/marketing/env/.env
SYNC=/tmp/marketing_env_sync
test -f "$ENVF"
test -f "$SYNC"
python3 - <<'PY'
from pathlib import Path

def upsert(path: Path, key: str, value: str) -> str:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    prefix = f"{key}="
    out = []
    replaced = False
    for line in lines:
        stripped = line.lstrip()
        if line.startswith(prefix) or stripped.startswith(f"# {prefix}") or stripped.startswith(f"#{prefix}"):
            out.append(f"{key}={value}\n")
            replaced = True
        else:
            out.append(line if line.endswith("\n") else line + "\n")
    if not replaced:
        if out and not out[-1].endswith("\n"):
            out[-1] += "\n"
        if out and out[-1].strip():
            out.append("\n")
        out.append(f"{key}={value}\n")
    path.write_text("".join(out), encoding="utf-8")
    return "updated" if replaced else "added"

path = Path("/opt/marketing/env/.env")
sync = Path("/tmp/marketing_env_sync")
for raw in sync.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, _, value = line.partition("=")
    key = key.strip()
    value = value.strip()
    if not key or not value:
        continue
    action = upsert(path, key, value)
    print(f"{key}: {action} len={len(value)}")
PY
chmod 600 "$ENVF"
chown root:root "$ENVF"
rm -f "$SYNC"
echo "remote env tokens synced"
REMOTE
else
  echo "Skipped token update (ROP01_UPDATE_TOKENS=0)"
fi

echo "=== remote scripts ==="
ssh "${SSH_OPTS[@]}" "$HOST" 'ls -la /opt/marketing/scripts'
echo "DONE"
