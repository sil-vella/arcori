#!/bin/bash
# dash Run Flutter arcori on Android
# Flutter arcori (flutter_base_06) on Android — env from wfrun only.
#
# Usage:
#   wfrun → launch_android.sh
#   launch_android.sh [adb_serial|1|oneplus|2|note58|doogee]
#
# During flutter run: V records the whole session (one file), X saves a screenshot.
# Both files go to automation/frontend/launch_android_assets/.
# After X, saying yes saves 3 Play Console images: phone, 7-inch tablet, 10-inch tablet.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${WFRUN_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
FLUTTER_DIR="$REPO_ROOT/app_codebase/flutter_base_06"

REMOTE_PATH="${REMOTE_PATH:-/data/local/tmp/wf_screenrecord_tmp.mp4}"
SCREENRECORD_BIT_RATE="${SCREENRECORD_BIT_RATE:-8000000}"
SCREENSHOTS_DIR="$REPO_ROOT/automation/frontend/launch_android_assets"
RECORDINGS_DIR="$SCREENSHOTS_DIR"
# Play Console store screenshots, 24-bit PNG (no alpha).
# Phone: 9:16 or 16:9, each side 320–3840 (1080×1920 meets the featuring minimum).
# 7-inch and 10-inch tablets: 9:16 or 16:9, each side 1080–7680.
PHONE_SHOT_PORTRAIT_W=1080
PHONE_SHOT_PORTRAIT_H=1920
PHONE_SHOT_LANDSCAPE_W=1920
PHONE_SHOT_LANDSCAPE_H=1080
TABLET7_SHOT_PORTRAIT_W=1080
TABLET7_SHOT_PORTRAIT_H=1920
TABLET7_SHOT_LANDSCAPE_W=1920
TABLET7_SHOT_LANDSCAPE_H=1080
TABLET10_SHOT_PORTRAIT_W=1440
TABLET10_SHOT_PORTRAIT_H=2560
TABLET10_SHOT_LANDSCAPE_W=2560
TABLET10_SHOT_LANDSCAPE_H=1440

# --- wfrun / env ---

require_wfrun() {
  if [[ -z "${WFRUN_MODE:-}" || -z "${WFRUN_PROFILE:-}" ]]; then
    echo "❌ Run via wfrun — this script expects exported env (WFRUN_MODE, WFRUN_PROFILE)."
    exit 1
  fi
  if [[ "$WFRUN_PROFILE" != frontend ]]; then
    echo "❌ WFRUN_PROFILE must be frontend (dart-defines env not loaded)."
    exit 1
  fi
}

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "❌ $name must be set in ${WFRUN_DART_DEFINES_FILE:-.env.dart.defines.*}"
    exit 1
  fi
}

warn_loopback_urls() {
  local api="$ARCORI_API_REST_URL"
  local api_ws="$ARCORI_API_WS_URL"
  local dart_ws="$ARCORI_DART_WS_URL"
  if [[ "$api" == *localhost* || "$api" == *127.0.0.1* ]]; then
    echo "   ⚠️  ARCORI_API_REST_URL is loopback — use LAN IP for physical devices" >&2
  fi
  if [[ "$api" == *10.0.2.2* ]]; then
    echo "   ⚠️  ARCORI_API_REST_URL uses 10.0.2.2 (emulator only)" >&2
  fi
  if [[ "$api_ws" == *localhost* || "$api_ws" == *127.0.0.1* ]]; then
    echo "   ⚠️  ARCORI_API_WS_URL is loopback — use LAN IP for physical devices" >&2
  fi
  if [[ "$dart_ws" == *localhost* || "$dart_ws" == *127.0.0.1* ]]; then
    echo "   ⚠️  ARCORI_DART_WS_URL is loopback — use LAN IP for physical devices" >&2
  fi
}

# --- device / adb ---

get_device_label() {
  case "$1" in
    84fbcf31) echo "OnePlus device" ;;
    NOTE58000000021664) echo "DOOGEE Note 58" ;;
    *) echo "Android device" ;;
  esac
}

resolve_device_id() {
  case "$1" in
    1|oneplus|OnePlus|ONEPLUS) echo "84fbcf31" ;;
    2|doogee|Doogee|DOOGEE|note58|Note58|NOTE58) echo "NOTE58000000021664" ;;
    *) echo "$1" ;;
  esac
}

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
  echo "❌ adb not found." >&2
  return 1
}

android_ensure_adb_path() {
  local adb_pt="${ANDROID_HOME:-${HOME}/Library/Android/sdk}/platform-tools"
  export PATH="$adb_pt:$PATH"
}

android_assert_device_connected() {
  local serial="$1"
  local adb
  adb="$(find_adb)" || return 1
  if ! "$adb" devices | awk 'NR>1 && $2=="device" {print $1}' | grep -qx "$serial"; then
    echo "❌ Device $serial not connected. Run: $adb devices" >&2
    return 1
  fi
  return 0
}

prompt_android_device() {
  echo "📲 Select target device:" >&2
  echo "   1) OnePlus (84fbcf31)" >&2
  echo "   2) DOOGEE Note 58 (NOTE58000000021664)" >&2
  local _tty=/dev/tty
  [[ -r "$_tty" ]] || _tty=/dev/stdin
  local choice=""
  if ! read -r -t 10 -p "Enter choice [1] (default: 1): " choice < "$_tty"; then
    echo "" >&2
    choice="1"
  fi
  case "${choice:-1}" in
    1|oneplus|OnePlus|ONEPLUS|"") echo "84fbcf31" ;;
    2|doogee|Doogee|DOOGEE|note58|Note58|NOTE58) echo "NOTE58000000021664" ;;
    *)
      echo "⚠️  Invalid choice, using 1 (OnePlus)" >&2
      echo "84fbcf31"
      ;;
  esac
}

# --- screenrecord (adb) ---
# Chains Android's 180s cap. Press V to stop and save one file.
# shellcheck source=android_screenrecord_lib.sh
source "$SCRIPT_DIR/android_screenrecord_lib.sh"

# --- screenshot (adb screencap) ---

_android_screenshot_is_png() {
  local file="$1"
  local magic
  [ -s "$file" ] || return 1
  magic="$(od -An -tx1 -N 4 "$file" 2>/dev/null | tr -d ' \n' | tr '[:upper:]' '[:lower:]')"
  [ "$magic" = "89504e47" ]
}

android_screenshot() {
  local serial="$1"
  local adb="${ADB:-$(find_adb)}"
  local now ts out_file
  now="$(date +%s)"
  if [ "${_screenshot_last:-0}" -gt 0 ] && [ $((now - _screenshot_last)) -lt 1 ]; then
    return 0
  fi
  _screenshot_last=$now

  ts="$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$SCREENSHOTS_DIR"
  out_file="$SCREENSHOTS_DIR/wf_shot_${ts}.png"
  echo "📸 Capturing screenshot…" >&2
  # flutter run already holds an adb shell for logcat. Another `adb shell`
  # (screencap to a device file, then pull) drops that session's VM-service
  # forward. Flutter then prints "Lost connection to device" and exits 0,
  # and this script follows it out as soon as the Play images are written.
  # exec-out is a raw command with stdin closed, so the debug session stays up.
  if ! "$adb" -s "$serial" exec-out screencap -p >"$out_file" </dev/null 2>/dev/null; then
    echo "❌ Screenshot failed on $serial" >&2
    rm -f "$out_file"
    return 1
  fi
  if ! _android_screenshot_is_png "$out_file"; then
    echo "❌ Screenshot file is not a PNG" >&2
    rm -f "$out_file"
    return 1
  fi
  echo "✅ Saved: $out_file" >&2
  android_screenshot_offer_tablet_copy "$out_file" || true
  return 0
}

_android_screenshot_px() {
  local file="$1"
  local key="$2"
  sips -g "$key" "$file" 2>/dev/null | awk -v k="$key:" '$1 == k { print $2; exit }'
}

android_screenshot_fit_copy() {
  local src="$1"
  local tw="$2"
  local th="$3"
  local out="$4"
  local label="$5"
  local w h
  w="$(_android_screenshot_px "$src" pixelWidth)"
  h="$(_android_screenshot_px "$src" pixelHeight)"
  if ! [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ && "$w" -gt 0 && "$h" -gt 0 ]]; then
    echo "❌ Could not read screenshot size for $label" >&2
    return 1
  fi
  # Scale the whole frame into the target. Do not crop. Pad with the app letterbox.
  if ! WF_SHOT_SRC="$src" WF_SHOT_OUT="$out" WF_SHOT_W="$tw" WF_SHOT_H="$th" python3 - << 'PY'
import os
from PIL import Image
src = os.environ["WF_SHOT_SRC"]
out = os.environ["WF_SHOT_OUT"]
tw = int(os.environ["WF_SHOT_W"])
th = int(os.environ["WF_SHOT_H"])
im = Image.open(src).convert("RGB")
im.thumbnail((tw, th), Image.Resampling.LANCZOS)
canvas = Image.new("RGB", (tw, th), (0x0F, 0x0E, 0x10))
canvas.paste(im, ((tw - im.width) // 2, (th - im.height) // 2))
canvas.save(out, "PNG")
PY
  then
    echo "❌ Failed to build $label screenshot" >&2
    rm -f "$out"
    return 1
  fi
  echo "✅ $label (${tw}×${th}): $out" >&2
}

android_screenshot_save_console_set() {
  local src="$1"
  local pw="$2"
  local ph="$3"
  local t7w="$4"
  local t7h="$5"
  local t10w="$6"
  local t10h="$7"
  local base name phone t7 t10
  base="${src%.png}"
  name="$(basename "$base")"
  mkdir -p "$SCREENSHOTS_DIR/android/phone" "$SCREENSHOTS_DIR/android/tablet10"
  phone="$SCREENSHOTS_DIR/android/phone/${name}_phone.png"
  t10="$SCREENSHOTS_DIR/android/tablet10/${name}_tablet10.png"
  t7=""
  if [ "$pw" != "$t7w" ] || [ "$ph" != "$t7h" ]; then
    mkdir -p "$SCREENSHOTS_DIR/android/tablet7"
    t7="$SCREENSHOTS_DIR/android/tablet7/${name}_tablet7.png"
  fi
  if android_screenshot_fit_copy "$src" "$pw" "$ph" "$phone" "Phone" \
    && { [ -z "$t7" ] || android_screenshot_fit_copy "$src" "$t7w" "$t7h" "$t7" "7-inch tablet"; } \
    && android_screenshot_fit_copy "$src" "$t10w" "$t10h" "$t10" "10-inch tablet"; then
    mkdir -p "$SCREENSHOTS_DIR/android/original"
    mv "$src" "$SCREENSHOTS_DIR/android/original/$(basename "$src")"
    echo "✅ Play Console set saved under android/phone and android/tablet10" >&2
    return 0
  fi
  rm -f "$phone" "$t7" "$t10"
  echo "⚠️  Kept the original snap because a store-listing copy failed: $src" >&2
  return 1
}

android_screenshot_offer_tablet_copy() {
  local src="$1"
  local w h pw ph t7w t7h t10w t10h answer
  if [[ ! -r /dev/tty ]]; then
    return 0
  fi
  if ! command -v sips >/dev/null 2>&1; then
    echo "⚠️  sips not available — skipped Play Console copies" >&2
    return 0
  fi
  w="$(_android_screenshot_px "$src" pixelWidth)"
  h="$(_android_screenshot_px "$src" pixelHeight)"
  if ! [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ && "$w" -gt 0 && "$h" -gt 0 ]]; then
    echo "⚠️  Could not read screenshot size — skipped Play Console copies" >&2
    return 0
  fi
  if [ "$h" -ge "$w" ]; then
    pw=$PHONE_SHOT_PORTRAIT_W
    ph=$PHONE_SHOT_PORTRAIT_H
    t7w=$TABLET7_SHOT_PORTRAIT_W
    t7h=$TABLET7_SHOT_PORTRAIT_H
    t10w=$TABLET10_SHOT_PORTRAIT_W
    t10h=$TABLET10_SHOT_PORTRAIT_H
  else
    pw=$PHONE_SHOT_LANDSCAPE_W
    ph=$PHONE_SHOT_LANDSCAPE_H
    t7w=$TABLET7_SHOT_LANDSCAPE_W
    t7h=$TABLET7_SHOT_LANDSCAPE_H
    t10w=$TABLET10_SHOT_LANDSCAPE_W
    t10h=$TABLET10_SHOT_LANDSCAPE_H
  fi
  echo "Align this snap to Play Console sizes and save 2 images? [y/N]" >&2
  echo "  phone ${pw}×${ph}  |  10-inch tablet ${t10w}×${t10h}" >&2
  if [ "$pw" = "$t7w" ] && [ "$ph" = "$t7h" ]; then
    echo "  7-inch tablet matches the phone size, so it is not saved again" >&2
  fi
  stty echo < /dev/tty 2>/dev/null || true
  if ! IFS= read -r -n 1 answer < /dev/tty; then
    stty -echo -icanon min 1 time 0 < /dev/tty 2>/dev/null || true
    return 0
  fi
  printf '\n' >&2
  stty -echo -icanon min 1 time 0 < /dev/tty 2>/dev/null || true
  case "$answer" in
    y|Y) android_screenshot_save_console_set "$src" "$pw" "$ph" "$t7w" "$t7h" "$t10w" "$t10h" || true ;;
  esac
  # Image work must not end flutter run. A non-zero sips status, or bash -e
  # treating that status as fatal, was dropping the session after the 3 files.
  return 0
}

# --- flutter run ---

ANDROID_PACKAGE_NAME="${ANDROID_PACKAGE_NAME:-com.reignofplay.arcori}"
FIREBASE_DEBUG_PROP_SET=0

is_firebase_switch_truthy() {
  local v
  v="$(echo "${FIREBASE_SWITCH:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$v" in true|1|yes) return 0 ;; *) return 1 ;; esac
}

dart_define_firebase_enabled() {
  local arg
  for arg in "${DART_DEFINE_ARGS[@]}"; do
    case "$arg" in
      --dart-define=FIREBASE_SWITCH=true|--dart-define=FIREBASE_SWITCH=1|--dart-define=FIREBASE_SWITCH=yes)
        return 0
        ;;
    esac
  done
  return 1
}

android_enable_firebase_debug_view() {
  if ! dart_define_firebase_enabled && ! is_firebase_switch_truthy; then
    echo "ℹ️  Firebase DebugView adb setprop skipped (FIREBASE_SWITCH not enabled in dart-defines)" >&2
    return 0
  fi
  if "$ADB" -s "$DEVICE_ID" shell setprop debug.firebase.analytics.app "$ANDROID_PACKAGE_NAME" 2>/dev/null; then
    FIREBASE_DEBUG_PROP_SET=1
    echo "📊 Firebase DebugView enabled for $ANDROID_PACKAGE_NAME (adb setprop)" >&2
  else
    echo "⚠️  Could not set Firebase DebugView property on $DEVICE_ID" >&2
  fi
}

android_disable_firebase_debug_view() {
  if [[ "$FIREBASE_DEBUG_PROP_SET" != 1 ]]; then
    return 0
  fi
  "$ADB" -s "$DEVICE_ID" shell setprop debug.firebase.analytics.app .none. 2>/dev/null || true
}

cleanup_on_exit() {
  if [[ "${_CLEANUP_DONE:-0}" == 1 ]]; then
    return 0
  fi
  _CLEANUP_DONE=1
  android_disable_firebase_debug_view
  if android_screenrecord_is_active "$DEVICE_ID" 2>/dev/null || _android_screenrecord_read_state "$DEVICE_ID" 2>/dev/null; then
    echo "⏹️  Stopping active screen record before exit…" >&2
    android_screenrecord_stop "$DEVICE_ID" || true
  fi
}

run_flutter_android_plain() {
  flutter run \
    -d "$DEVICE_ID" \
    "${DART_DEFINE_ARGS[@]}" \
    2>&1 | filter_flutter_to_global_log
  return "${PIPESTATUS[0]}"
}

_key_fifo=""
_key_fifo_out=""
_key_tty_settings=""

restore_key_tty() {
  rm -f "$_key_fifo" "$_key_fifo_out"
  if [[ -n "${_key_tty_settings:-}" ]]; then
    stty "$_key_tty_settings" < /dev/tty 2>/dev/null || true
  else
    stty sane < /dev/tty 2>/dev/null || true
  fi
  _key_tty_settings=""
}

on_key_runner_signal() {
  local code="${1:-130}"
  restore_key_tty
  cleanup_on_exit
  exit "$code"
}

run_flutter_android_with_keys() {
  local pid filter_pid key flutter_exit
  _key_fifo="$(mktemp -u "${TMPDIR:-/tmp}/flutter_stdin.XXXXXX")"
  _key_fifo_out="$(mktemp -u "${TMPDIR:-/tmp}/flutter_stdout.XXXXXX")"
  mkfifo "$_key_fifo"
  mkfifo "$_key_fifo_out"

  trap 'restore_key_tty; cleanup_on_exit' EXIT
  trap 'on_key_runner_signal 130' INT
  trap 'on_key_runner_signal 143' TERM
  trap 'on_key_runner_signal 129' HUP

  flutter run \
    -d "$DEVICE_ID" \
    "${DART_DEFINE_ARGS[@]}" \
    < "$_key_fifo" >"$_key_fifo_out" 2>&1 &
  pid=$!

  filter_flutter_to_global_log <"$_key_fifo_out" &
  filter_pid=$!

  exec 3>"$_key_fifo"

  _key_tty_settings="$(stty -g < /dev/tty)"
  stty -echo -icanon min 1 time 0 < /dev/tty 2>/dev/null || true

  set +e
  while kill -0 "$pid" 2>/dev/null; do
    if ! IFS= read -r -n 1 key < /dev/tty 2>/dev/null; then
      sleep 0.05
      continue
    fi
    case "$key" in
      $'\x03')
        kill "$pid" 2>/dev/null || true
        break
        ;;
      X|x)
        # Subshell so a failure inside screenshot/sips cannot tear down this
        # shell. Close only this copy of the flutter stdin fifo, and drop
        # traps so a subshell exit cannot restore the tty or remove the fifos.
        (
          trap - EXIT INT TERM HUP 2>/dev/null || true
          exec 3>&-
          set +e
          android_screenshot "$DEVICE_ID"
        ) || true
        stty -echo -icanon min 1 time 0 < /dev/tty 2>/dev/null || true
        ;;
      V|v)
        android_screenrecord_toggle "$DEVICE_ID"
        ;;
      *)
        printf '%s' "$key" >&3
        ;;
    esac
  done
  set -e

  wait "$pid" 2>/dev/null || true
  flutter_exit=$?
  wait "$filter_pid" 2>/dev/null || true
  return "$flutter_exit"
}

run_flutter_android() {
  if [[ -r /dev/tty ]]; then
    run_flutter_android_with_keys
  else
    echo "⚠️  No terminal — screenshot (X) and screen record (V) keys are unavailable." >&2
    run_flutter_android_plain
  fi
}

# --- main ---

require_wfrun

require_var ARCORI_API_REST_URL
require_var ARCORI_API_WS_URL
require_var ARCORI_DART_WS_URL

android_ensure_adb_path

if [[ -n "${1:-}" ]]; then
  DEVICE_ID="$(resolve_device_id "$1")"
else
  DEVICE_ID="$(prompt_android_device)"
fi
DEVICE_LABEL="$(get_device_label "$DEVICE_ID")"
android_assert_device_connected "$DEVICE_ID" || exit 1

ADB="$(find_adb)"
export ADB REPO_ROOT RECORDINGS_DIR REMOTE_PATH SCREENRECORD_BIT_RATE
export SCREENRECORD_TIME_LIMIT="${SCREENRECORD_TIME_LIMIT:-180}"
if [ -n "${SCREENRECORD_SIZE:-}" ]; then
  export SCREENRECORD_SIZE
fi
trap cleanup_on_exit EXIT INT TERM HUP

if [[ ! -d "$FLUTTER_DIR" ]]; then
  echo "❌ Flutter project not found: $FLUTTER_DIR"
  exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPT_DIR/dart_defines_from_env.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/global_log_filter.sh"

DART_DEFINE_ARGS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && DART_DEFINE_ARGS+=("$line")
done < <(build_dart_defines_from_wfrun_env)

android_enable_firebase_debug_view

echo "📱 wfrun ($WFRUN_MODE): API=$ARCORI_API_REST_URL  Dart WS=$ARCORI_DART_WS_URL  API WS=$ARCORI_API_WS_URL"
echo "📱 device=$DEVICE_LABEL ($DEVICE_ID)"
mkdir -p "$SCREENSHOTS_DIR"
echo "📱 recordings and screenshots → $SCREENSHOTS_DIR/"
warn_loopback_urls
echo "🎯 flutter run -d $DEVICE_ID (project: $FLUTTER_DIR)"
if [[ -r /dev/tty ]]; then
  echo "⌨️  Press X during flutter run to screenshot the device"
  echo "⌨️  Press V during flutter run to record the whole session (one file when you press V again)"
fi

cd "$FLUTTER_DIR"
run_flutter_android
exit $?
