#!/usr/bin/env bash
# adb screenrecord start/stop/toggle for wf_template / Arcori launch_android.sh.
# Chains Android's 180s cap into one session file.


: "${RECORDINGS_DIR:=$REPO_ROOT/recordings}"
_ANDROID_SCREENRECORD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# /data/local/tmp is reliable for adb pull on physical devices (OnePlus, etc.)
: "${REMOTE_PATH:=/data/local/tmp/wf_screenrecord_tmp.mp4}"
: "${SCREENRECORD_BIT_RATE:=8000000}"
# adb screenrecord rejects anything above 180.
: "${SCREENRECORD_TIME_LIMIT:=180}"

_android_rec_state_file() {
  local serial="$1"
  echo "${TMPDIR:-/tmp}/wf_screenrecord_${serial}.state"
}

_android_rec_session_file() {
  local serial="$1"
  echo "${TMPDIR:-/tmp}/wf_screenrecord_${serial}.session"
}

_android_rec_watch_pid_file() {
  local serial="$1"
  echo "${TMPDIR:-/tmp}/wf_screenrecord_${serial}.watchpid"
}

_android_rec_watch_run_file() {
  local serial="$1"
  echo "${TMPDIR:-/tmp}/wf_screenrecord_${serial}.watchrun"
}

_android_rec_lock_dir() {
  local serial="$1"
  echo "${TMPDIR:-/tmp}/wf_screenrecord_${serial}.lock"
}

android_screenrecord_is_active() {
  local serial="$1"
  [ -f "$(_android_rec_session_file "$serial")" ]
}

_android_screenrecord_remote_exists() {
  local serial="$1"
  local adb="${ADB:-$(find_adb)}"
  local path="$2"
  "$adb" -s "$serial" shell "[ -f '$path' ]" >/dev/null 2>&1
}

_android_screenrecord_resolve_remote_path() {
  local serial="$1"
  if _android_screenrecord_remote_exists "$serial" "$REMOTE_PATH"; then
    echo "$REMOTE_PATH"
    return 0
  fi
  if _android_screenrecord_remote_exists "$serial" "/sdcard/wf_screenrecord_tmp.mp4"; then
    echo "/sdcard/wf_screenrecord_tmp.mp4"
    return 0
  fi
  return 1
}

_android_screenrecord_remote_size() {
  local serial="$1"
  local adb="${ADB:-$(find_adb)}"
  local path="$2"
  local raw
  raw="$("$adb" -s "$serial" shell "wc -c < '$path' 2>/dev/null" 2>/dev/null | tr -d '\r' | awk '{print $1}')"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    echo "$raw"
  else
    echo "0"
  fi
}

_android_screenrecord_wait_remote_stable() {
  local serial="$1"
  local path="$2"
  local prev_size="-1"
  local stable=0
  local i=0
  while [ "$i" -lt 48 ]; do
    if ! _android_screenrecord_remote_exists "$serial" "$path"; then
      sleep 0.25
      i=$((i + 1))
      continue
    fi
    local size
    size="$(_android_screenrecord_remote_size "$serial" "$path")"
    if [ "$size" -gt 0 ] && [ "$size" = "$prev_size" ]; then
      stable=$((stable + 1))
      if [ "$stable" -ge 4 ]; then
        return 0
      fi
    else
      stable=0
      prev_size="$size"
    fi
    sleep 0.25
    i=$((i + 1))
  done
  return 1
}

_android_screenrecord_local_playable() {
  local file="$1"
  [ -f "$file" ] || return 1
  [ "$(wc -c <"$file" | tr -d ' ')" -gt 4096 ] || return 1
  if command -v ffprobe >/dev/null 2>&1; then
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" >/dev/null 2>&1
    return $?
  fi
  # Fallback: playable MP4 should contain a moov atom near the end.
  strings "$file" 2>/dev/null | grep -q moov
}

_android_screenrecord_read_state() {
  local serial="$1"
  local state_file
  state_file="$(_android_rec_state_file "$serial")"
  OUT_FILE=""
  HOST_PID=""
  REMOTE_FILE=""
  if [ ! -f "$state_file" ]; then
    return 1
  fi
  IFS='|' read -r _serial OUT_FILE HOST_PID REMOTE_FILE <"$state_file" || true
  if [ -z "$OUT_FILE" ]; then
    return 1
  fi
  if [ -z "$REMOTE_FILE" ]; then
    REMOTE_FILE="$REMOTE_PATH"
  fi
  return 0
}

_android_screenrecord_write_state() {
  local serial="$1"
  local out_file="$2"
  local host_pid="$3"
  local remote_path="$4"
  local state_file
  state_file="$(_android_rec_state_file "$serial")"
  printf '%s|%s|%s|%s\n' "$serial" "$out_file" "$host_pid" "$remote_path" >"$state_file"
}

_android_screenrecord_stop_host_shell() {
  local host_pid="$1"
  [ -n "$host_pid" ] || return 1
  if ! kill -0 "$host_pid" 2>/dev/null; then
    return 0
  fi
  kill -INT "$host_pid" 2>/dev/null || kill -2 "$host_pid" 2>/dev/null || true
  local w=0
  while kill -0 "$host_pid" 2>/dev/null && [ "$w" -lt 24 ]; do
    sleep 0.25
    w=$((w + 1))
  done
  if kill -0 "$host_pid" 2>/dev/null; then
    kill -TERM "$host_pid" 2>/dev/null || true
    sleep 0.5
    kill -KILL "$host_pid" 2>/dev/null || true
  fi
  return 0
}

_android_screenrecord_device_running() {
  local serial="$1"
  local adb="${ADB:-$(find_adb)}"
  local pid
  pid="$("$adb" -s "$serial" shell pidof screenrecord 2>/dev/null | tr -d '\r' | awk '{print $1}')"
  [ -n "$pid" ] && [ "$pid" != "0" ]
}

_android_screenrecord_signal_device_stop() {
  local serial="$1"
  local adb="${ADB:-$(find_adb)}"
  "$adb" -s "$serial" shell "pid=\$(pidof screenrecord 2>/dev/null | awk '{print \$1}'); if [ -n \"\$pid\" ]; then kill -INT \$pid; fi" 2>/dev/null || true
  "$adb" -s "$serial" shell pkill -INT screenrecord 2>/dev/null || true
  "$adb" -s "$serial" shell pkill -l 2 screenrecord 2>/dev/null || true
}

# kill -0 is true for a zombie. A finished adb screenrecord stays a zombie until this shell waits.
_android_screenrecord_host_running() {
  local host_pid="$1"
  local state=""
  [ -n "$host_pid" ] || return 1
  kill -0 "$host_pid" 2>/dev/null || return 1
  state="$(ps -o state= -p "$host_pid" 2>/dev/null | tr -d '[:space:]')"
  case "${state:-}" in
    Z*) return 1 ;;
  esac
  return 0
}

_android_screenrecord_finish_host() {
  local host_pid="$1"
  local state=""
  [ -n "$host_pid" ] || return 0
  if kill -0 "$host_pid" 2>/dev/null; then
    state="$(ps -o state= -p "$host_pid" 2>/dev/null | tr -d '[:space:]')"
    case "${state:-}" in
      Z*)
        wait "$host_pid" 2>/dev/null || true
        return 0
        ;;
    esac
    _android_screenrecord_stop_host_shell "$host_pid"
  fi
  wait "$host_pid" 2>/dev/null || true
}

_android_screenrecord_lock() {
  local serial="$1"
  local dir i
  dir="$(_android_rec_lock_dir "$serial")"
  i=0
  while ! mkdir "$dir" 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -ge 400 ]; then
      return 1
    fi
    sleep 0.05
  done
}

_android_screenrecord_unlock() {
  local serial="$1"
  rm -rf "$(_android_rec_lock_dir "$serial")"
}

_android_screenrecord_clear_stale() {
  local serial="$1"
  local adb="${ADB:-$(find_adb)}"
  local host_pid=""
  local remote_path=""
  if _android_screenrecord_read_state "$serial"; then
    host_pid="$HOST_PID"
    remote_path="$REMOTE_FILE"
  fi
  if [ -n "$host_pid" ]; then
    _android_screenrecord_finish_host "$host_pid"
  fi
  rm -f "$(_android_rec_state_file "$serial")"
  if _android_screenrecord_device_running "$serial"; then
    echo "⚠️  Clearing stale screenrecord on device…" >&2
    _android_screenrecord_signal_device_stop "$serial"
    sleep 1
  fi
  if [ -n "$remote_path" ]; then
    "$adb" -s "$serial" shell rm -f "$REMOTE_PATH" /sdcard/wf_screenrecord_tmp.mp4 "$remote_path" 2>/dev/null || true
  else
    "$adb" -s "$serial" shell rm -f "$REMOTE_PATH" /sdcard/wf_screenrecord_tmp.mp4 2>/dev/null || true
  fi
}

_android_screenrecord_save_clip() {
  local serial="$1"
  local out_file="$2"
  local remote_path="$3"
  local adb="${ADB:-$(find_adb)}"

  if [ -z "$out_file" ] || [ -z "$remote_path" ]; then
    echo "❌ No recording path to save." >&2
    return 1
  fi

  if ! _android_screenrecord_remote_exists "$serial" "$remote_path"; then
    if _android_screenrecord_remote_exists "$serial" "$REMOTE_PATH"; then
      remote_path="$REMOTE_PATH"
    elif _android_screenrecord_remote_exists "$serial" "/sdcard/wf_screenrecord_tmp.mp4"; then
      remote_path="/sdcard/wf_screenrecord_tmp.mp4"
    else
      echo "❌ No recording file on device to save." >&2
      return 1
    fi
  fi

  _android_screenrecord_wait_remote_stable "$serial" "$remote_path" || true

  local tmp_pull="${out_file}.pulling"
  rm -f "$tmp_pull"
  if ! "$adb" -s "$serial" pull "$remote_path" "$tmp_pull"; then
    echo "❌ Failed to pull recording to $out_file" >&2
    rm -f "$tmp_pull"
    return 1
  fi
  mv -f "$tmp_pull" "$out_file"

  if ! _android_screenrecord_local_playable "$out_file"; then
    echo "❌ Recording file is not playable (missing MP4 metadata): $out_file" >&2
    echo "   Left on disk. Try: adb -s $serial shell screenrecord --time-limit 10 $remote_path" >&2
    "$adb" -s "$serial" shell rm -f "$remote_path" 2>/dev/null || true
    return 1
  fi

  "$adb" -s "$serial" shell rm -f "$remote_path" 2>/dev/null || true
  echo "✅ Saved: $out_file" >&2
  if command -v open >/dev/null 2>&1; then
    echo "   open \"$out_file\"" >&2
  fi
}

_android_screenrecord_start_segment() {
  local serial="$1"
  local adb="${ADB:-$(find_adb)}"
  local ts out_file remote host_pid ok i

  ts="$(date +%Y%m%d_%H%M%S)_${RANDOM}"
  mkdir -p "$RECORDINGS_DIR"
  out_file="$RECORDINGS_DIR/wf_screen_${ts}.mp4"
  remote="/data/local/tmp/wf_screen_${ts}.mp4"

  # stdin from /dev/null so this adb shell does not take keys from flutter run.
  if [ -n "${SCREENRECORD_SIZE:-}" ]; then
    "$adb" -s "$serial" shell screenrecord --time-limit "$SCREENRECORD_TIME_LIMIT" --bit-rate "$SCREENRECORD_BIT_RATE" \
      --size "$SCREENRECORD_SIZE" "$remote" </dev/null &
  else
    "$adb" -s "$serial" shell screenrecord --time-limit "$SCREENRECORD_TIME_LIMIT" --bit-rate "$SCREENRECORD_BIT_RATE" \
      "$remote" </dev/null &
  fi
  host_pid=$!

  ok=0
  i=0
  while [ "$i" -lt 25 ]; do
    if _android_screenrecord_device_running "$serial"; then
      ok=1
      break
    fi
    if ! kill -0 "$host_pid" 2>/dev/null; then
      break
    fi
    sleep 0.2
    i=$((i + 1))
  done

  if [ "$ok" != 1 ]; then
    _android_screenrecord_finish_host "$host_pid"
    if [ "${2:-}" != quiet ]; then
      echo "❌ screenrecord did not start on $serial (try: adb -s $serial shell pidof screenrecord)" >&2
    fi
    return 1
  fi

  _android_screenrecord_write_state "$serial" "$out_file" "$host_pid" "$remote"
  echo "🎬 Recording → $out_file" >&2
}

_android_screenrecord_notify() {
  local msg="$1"
  echo "$msg" >&2
  if [ -w /dev/tty ]; then
    echo "$msg" >/dev/tty 2>/dev/null || true
  fi
}

_android_screenrecord_result_file() {
  local serial="$1"
  echo "${TMPDIR:-/tmp}/wf_screenrecord_${serial}.result"
}

_android_screenrecord_daemon_pid_file() {
  local serial="$1"
  echo "${TMPDIR:-/tmp}/wf_screenrecord_${serial}.watchpid"
}

_android_screenrecord_daemon_alive() {
  local serial="$1"
  local pid_file pid
  pid_file="$(_android_screenrecord_daemon_pid_file "$serial")"
  [ -f "$pid_file" ] || return 1
  pid="$(tr -d '[:space:]' <"$pid_file" 2>/dev/null || true)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

_android_screenrecord_concat_parts() {
  local list="$1"
  local final="$2"
  local serial="$3"
  local count only
  count="$(grep -c . "$list" 2>/dev/null || echo 0)"
  if [ "$count" -eq 0 ]; then
    _android_screenrecord_notify "❌ No playable clips to save."
    return 1
  fi
  if [ "$count" -eq 1 ]; then
    only="$(sed -n "1s/^file '//; 1s/'$//p" "$list")"
    mv -f "$only" "$final"
  elif command -v ffmpeg >/dev/null 2>&1; then
    if ! ffmpeg -y -loglevel error -f concat -safe 0 -i "$list" -c copy "$final"; then
      _android_screenrecord_notify "❌ Could not join parts. Individual clips stay in $RECORDINGS_DIR."
      return 1
    fi
    sed -n "s/^file '//; s/'$//p" "$list" | while IFS= read -r part; do
      [ "$part" = "$final" ] || rm -f "$part"
    done
  else
    _android_screenrecord_notify "❌ ffmpeg not found. Parts were left in $RECORDINGS_DIR."
    return 1
  fi
  rm -f "$list"
  _android_screenrecord_notify "✅ Saved full session: $final"
  printf '%s\n' "$final" >"$(_android_screenrecord_result_file "$serial")"
}

_android_screenrecord_daemon_main() {
  local serial="$1"
  local session_file session_ts final_file part_list host_pid out_file remote keep next_started
  set +e
  session_file="$(_android_rec_session_file "$serial")"
  session_ts="$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$RECORDINGS_DIR"
  final_file="$RECORDINGS_DIR/wf_session_${session_ts}.mp4"
  part_list="$RECORDINGS_DIR/.wf_session_${session_ts}.list"
  : >"$part_list"
  _android_screenrecord_notify "🎬 Session recording on. Android caps each part at ${SCREENRECORD_TIME_LIMIT}s; parts are joined when you press V."

  if ! _android_screenrecord_start_segment "$serial"; then
    rm -f "$session_file"
    return 1
  fi

  while true; do
    if ! _android_screenrecord_read_state "$serial"; then
      break
    fi
    host_pid="$HOST_PID"
    out_file="$OUT_FILE"
    remote="$REMOTE_FILE"
    while [ -f "$session_file" ] && _android_screenrecord_host_running "$host_pid"; do
      sleep 0.5
    done
    keep=0
    if [ -f "$session_file" ]; then
      keep=1
    fi
    if _android_screenrecord_host_running "$host_pid"; then
      kill -INT "$host_pid" 2>/dev/null || true
    fi
    wait "$host_pid" 2>/dev/null || true

    next_started=0
    if [ "$keep" = 1 ]; then
      if _android_screenrecord_start_segment "$serial"; then
        next_started=1
        _android_screenrecord_notify "⏱️ Part reached ${SCREENRECORD_TIME_LIMIT}s — next part started."
      else
        _android_screenrecord_notify "❌ Next part did not start. Saving what was recorded."
        rm -f "$session_file"
      fi
    fi

    if _android_screenrecord_save_clip "$serial" "$out_file" "$remote"; then
      printf "file '%s'\n" "$out_file" >>"$part_list"
    fi
    if [ "$next_started" != 1 ]; then
      break
    fi
  done

  _android_screenrecord_concat_parts "$part_list" "$final_file" "$serial" || true
  rm -f "$(_android_rec_state_file "$serial")" "$session_file" "$part_list"
}

_android_screenrecord_launch_daemon() {
  local serial="$1"
  local pid_file daemon log_file
  pid_file="$(_android_screenrecord_daemon_pid_file "$serial")"
  log_file="$RECORDINGS_DIR/screenrecord.log"
  mkdir -p "$RECORDINGS_DIR"
  if _android_screenrecord_daemon_alive "$serial"; then
    return 0
  fi
  # New session so Ctrl+C in flutter run does not kill the capture.
  python3 -c 'import os,sys; os.setsid(); os.execvp(sys.argv[1], sys.argv[1:])' \
    bash "$_ANDROID_SCREENRECORD_LIB_DIR/android_screenrecord_daemon.sh" "$serial" \
    </dev/null >>"$log_file" 2>&1 &
  daemon=$!
  echo "$daemon" >"$pid_file"
  disown "$daemon" 2>/dev/null || true
}

_android_screenrecord_wait_daemon() {
  local serial="$1"
  local pid_file pid w
  pid_file="$(_android_screenrecord_daemon_pid_file "$serial")"
  pid=""
  if [ -f "$pid_file" ]; then
    pid="$(tr -d '[:space:]' <"$pid_file" 2>/dev/null || true)"
  fi
  if [ -z "$pid" ]; then
    return 0
  fi
  w=0
  while kill -0 "$pid" 2>/dev/null && [ "$w" -lt 720 ]; do
    sleep 0.25
    w=$((w + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null || true
  fi
  wait "$pid" 2>/dev/null || true
  rm -f "$pid_file"
}

_android_screenrecord_stop_watcher() {
  local serial="$1"
  rm -f "$(_android_rec_watch_run_file "$serial")"
  _android_screenrecord_wait_daemon "$serial"
}

android_screenrecord_start() {
  local serial="$1"
  local i

  if ! _android_screenrecord_lock "$serial"; then
    echo "❌ Screen record is busy. Press V again in a moment." >&2
    return 1
  fi
  if android_screenrecord_is_active "$serial" && _android_screenrecord_daemon_alive "$serial"; then
    _android_screenrecord_unlock "$serial"
    echo "⚠️  Screen record already running on $serial (press V again to stop)." >&2
    return 0
  fi
  rm -f "$(_android_rec_session_file "$serial")"
  if _android_screenrecord_read_state "$serial" || _android_screenrecord_daemon_alive "$serial"; then
    _android_screenrecord_unlock "$serial"
    echo "⏹️  Saving the previous clip first." >&2
    android_screenrecord_stop "$serial" || true
    if ! _android_screenrecord_lock "$serial"; then
      return 1
    fi
  fi

  _android_screenrecord_clear_stale "$serial"
  rm -f "$(_android_screenrecord_result_file "$serial")"
  touch "$(_android_rec_session_file "$serial")"
  _android_screenrecord_launch_daemon "$serial"
  _android_screenrecord_unlock "$serial"

  i=0
  while [ "$i" -lt 40 ]; do
    if _android_screenrecord_device_running "$serial"; then
      echo "🎬 Recording the whole session (no audio). Press V to stop and save one file → $RECORDINGS_DIR/" >&2
      return 0
    fi
    if ! _android_screenrecord_daemon_alive "$serial"; then
      break
    fi
    sleep 0.25
    i=$((i + 1))
  done
  rm -f "$(_android_rec_session_file "$serial")"
  echo "❌ screenrecord did not start on $serial (see $RECORDINGS_DIR/screenrecord.log)" >&2
  return 1
}

android_screenrecord_stop() {
  local serial="$1"
  local host_pid="" result

  if ! _android_screenrecord_lock "$serial"; then
    echo "❌ Screen record is busy. Press V again in a moment." >&2
    return 1
  fi
  rm -f "$(_android_rec_session_file "$serial")" "$(_android_rec_watch_run_file "$serial")"
  if _android_screenrecord_read_state "$serial"; then
    host_pid="$HOST_PID"
  fi
  _android_screenrecord_unlock "$serial"

  if ! _android_screenrecord_daemon_alive "$serial"; then
    if [ -n "$host_pid" ] && _android_screenrecord_read_state "$serial"; then
      echo "⏹️  Saving the clip left on the device..." >&2
      _android_screenrecord_finish_host "$HOST_PID"
      _android_screenrecord_save_clip "$serial" "$OUT_FILE" "$REMOTE_FILE" || true
      rm -f "$(_android_rec_state_file "$serial")"
      return 0
    fi
    echo "⚠️  No active screen record on $serial (press V to start)." >&2
    return 0
  fi

  echo "⏹️  Stopping screen record and joining parts..." >&2
  if [ -n "$host_pid" ]; then
    _android_screenrecord_finish_host "$host_pid"
  fi
  _android_screenrecord_signal_device_stop "$serial"
  _android_screenrecord_wait_daemon "$serial"

  result="$(_android_screenrecord_result_file "$serial")"
  if [ -s "$result" ]; then
    echo "✅ Saved full session: $(cat "$result")" >&2
    return 0
  fi
  echo "❌ Recording did not save. See $RECORDINGS_DIR/screenrecord.log" >&2
  return 1
}

android_screenrecord_toggle() {
  local serial="$1"
  if android_screenrecord_is_active "$serial" || _android_screenrecord_read_state "$serial"; then
    android_screenrecord_stop "$serial"
  else
    android_screenrecord_start "$serial"
  fi
}
