#!/usr/bin/env bash
# pre_build_config_adjust(ios) — repo-specific release prep for Xcode Cloud.
# Sourced from ci_pre_xcodebuild.sh after version sync, before dart-defines / build.
#
# Requires: FLUTTER_APP_DIR (set by ci_pre_xcodebuild.sh).

set -euo pipefail

_disable_logging_switch_for_release() {
  local flutter_dir="${FLUTTER_APP_DIR:-}"
  if [ -z "$flutter_dir" ] || [ ! -d "$flutter_dir" ]; then
    echo "pre_build_config_adjust_ios: FLUTTER_APP_DIR not set" >&2
    return 1
  fi

  echo "🔇 Disabling LOGGING_SWITCH in Flutter sources..."
  local logging_switch_variable_value="true"
  local replaced_files=0

  while IFS= read -r -d '' dart_file; do
    if grep -q "LOGGING_SWITCH = ${logging_switch_variable_value}" "$dart_file" 2>/dev/null || \
       grep -q "const bool LOGGING_SWITCH = ${logging_switch_variable_value}" "$dart_file" 2>/dev/null || \
       grep -q "static const bool LOGGING_SWITCH = ${logging_switch_variable_value}" "$dart_file" 2>/dev/null; then
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/LOGGING_SWITCH = ${logging_switch_variable_value}/LOGGING_SWITCH = false/g" "$dart_file"
        sed -i '' "s/const bool LOGGING_SWITCH = ${logging_switch_variable_value}/const bool LOGGING_SWITCH = false/g" "$dart_file"
        sed -i '' "s/static const bool LOGGING_SWITCH = ${logging_switch_variable_value}/static const bool LOGGING_SWITCH = false/g" "$dart_file"
      else
        sed -i "s/LOGGING_SWITCH = ${logging_switch_variable_value}/LOGGING_SWITCH = false/g" "$dart_file"
        sed -i "s/const bool LOGGING_SWITCH = ${logging_switch_variable_value}/const bool LOGGING_SWITCH = false/g" "$dart_file"
        sed -i "s/static const bool LOGGING_SWITCH = ${logging_switch_variable_value}/static const bool LOGGING_SWITCH = false/g" "$dart_file"
      fi
      replaced_files=$((replaced_files + 1))
    fi
  done < <(find "$flutter_dir" -name "*.dart" -type f -print0)

  if [ "$replaced_files" -eq 0 ]; then
    echo "  ℹ️  No LOGGING_SWITCH = true found (already disabled or not present)."
  else
    echo "  ✅ Disabled LOGGING_SWITCH in $replaced_files file(s)"
  fi
  echo ""
}

# Entry point — add more iOS pre-build config steps here.
pre_build_config_adjust_ios() {
  _disable_logging_switch_for_release
}
