#!/usr/bin/env bash
# Long-lived screenrecord session. Chains adb's 180s limit and joins the parts.
set +e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

find_adb() {
  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return 0
  fi
  local sdk_adb="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
  if [ -x "$sdk_adb" ]; then
    echo "$sdk_adb"
    return 0
  fi
  echo "adb not found" >&2
  return 1
}

# shellcheck source=android_screenrecord_lib.sh
source "$SCRIPT_DIR/android_screenrecord_lib.sh"
_android_screenrecord_daemon_main "${1:?serial required}"
