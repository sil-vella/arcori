#!/usr/bin/env bash
# Shared Xcode Cloud / iOS release prebuild (env, version sync, dart-defines).
# Repo-specific steps: pre_build_config_adjust_ios.sh (sourced from ci_pre_xcodebuild.sh).
#
# Requires: REPO_ROOT, FLUTTER_APP_DIR (set by ci_pre_xcodebuild.sh).
# Exports: DART_DEFINES_ENV, FRONTEND_ENV, DART_DEF_JSON, APP_VERSION, BUILD_NUMBER

set -euo pipefail

_IOS_RELEASE_PREBUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCODE_CLOUD_BUILD_NUMBER_FILE="flutter_base_05/ios/xcode_cloud_build_number.txt"

# --- Materialize .env from Xcode Cloud secrets --------------------------------

xcode_cloud_materialize_env() {
  local root="${REPO_ROOT:-}"
  if [ -z "$root" ]; then
    echo "xcode_cloud_materialize_env: REPO_ROOT not set" >&2
    return 1
  fi

  local dart_env="$root/.env.dart.defines.prod"
  local frontend_env="$root/.env.prod"

  if [ -f "$dart_env" ]; then
    echo "📝 Using existing $dart_env"
  elif [ -n "${DUTCH_DART_DEFINES_PROD_B64:-}" ]; then
    echo "📝 Decoding DUTCH_DART_DEFINES_PROD_B64 → $dart_env"
    printf '%s' "$DUTCH_DART_DEFINES_PROD_B64" | base64 -d >"$dart_env"
  else
    echo "❌ Missing $dart_env and DUTCH_DART_DEFINES_PROD_B64 workflow secret." >&2
    echo "   App Store Connect → Xcode Cloud → Workflow → Environment" >&2
    echo "   Generate: base64 -i .env.dart.defines.prod | pbcopy" >&2
    return 1
  fi

  if [ ! -s "$dart_env" ]; then
    echo "❌ $dart_env is empty after materialize" >&2
    return 1
  fi

  if [ -f "$frontend_env" ]; then
    echo "📝 Using existing $frontend_env"
  elif [ -n "${DUTCH_ENV_PROD_B64:-}" ]; then
    echo "📝 Decoding DUTCH_ENV_PROD_B64 → $frontend_env"
    printf '%s' "$DUTCH_ENV_PROD_B64" | base64 -d >"$frontend_env"
  else
    echo "ℹ️  No $frontend_env (optional); version from pubspec.yaml"
  fi

  export DART_DEFINES_ENV="$dart_env"
  export FRONTEND_ENV="$frontend_env"
}

# --- Version sync (pubspec + Xcode project + ASC floor) ----------------------

compute_build_number_from_version() {
  local ver="$1"
  local ma mi pa
  IFS='.' read -r ma mi pa <<< "$ver"
  ma=${ma:-0}; mi=${mi:-0}; pa=${pa:-0}
  if ! [[ "$ma" =~ ^[0-9]+$ ]]; then ma=0; fi
  if ! [[ "$mi" =~ ^[0-9]+$ ]]; then mi=0; fi
  if ! [[ "$pa" =~ ^[0-9]+$ ]]; then pa=0; fi
  echo $((ma * 10000 + mi * 100 + pa))
}

version_string_from_build_number() {
  local build_number="$1"
  if ! [[ "$build_number" =~ ^[0-9]+$ ]]; then
    echo "version_string_from_build_number: invalid build number: $build_number" >&2
    return 1
  fi
  local ma mi pa
  ma=$((build_number / 10000))
  mi=$(((build_number % 10000) / 100))
  pa=$((build_number % 100))
  echo "${ma}.${mi}.${pa}"
}

read_ios_runner_build_number() {
  local root="${REPO_ROOT:-}"
  local pbxproj="$root/flutter_base_05/ios/Runner.xcodeproj/project.pbxproj"
  if [ ! -f "$pbxproj" ]; then
    echo 0
    return 0
  fi
  python3 - "$pbxproj" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
block_re = re.compile(
    r"\t\t\w+ /\* \w+ \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};",
    re.DOTALL,
)
versions = []
for block in block_re.findall(text):
    if "INFOPLIST_FILE = Runner/Info.plist;" not in block:
        continue
    match = re.search(r"\t\t\t\tCURRENT_PROJECT_VERSION = (\d+);", block)
    if match:
        versions.append(int(match.group(1)))
print(max(versions) if versions else 0)
PY
}

read_xcode_cloud_build_floor() {
  local root="${REPO_ROOT:-}"
  local floor=0
  local floor_file="$root/${XCODE_CLOUD_BUILD_NUMBER_FILE}"
  if [ -f "$floor_file" ]; then
    floor=$(tr -d '[:space:]' < "$floor_file")
    if ! [[ "$floor" =~ ^[0-9]+$ ]]; then
      floor=0
    fi
  fi
  local pbx_floor
  pbx_floor=$(read_ios_runner_build_number)
  if [[ "$pbx_floor" =~ ^[0-9]+$ ]] && [ "$pbx_floor" -gt "$floor" ]; then
    floor=$pbx_floor
  fi
  echo "$floor"
}

write_xcode_cloud_build_floor() {
  local build_number="$1"
  local root="${REPO_ROOT:-}"
  if [ -z "$root" ] || ! [[ "$build_number" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  local floor_file="$root/${XCODE_CLOUD_BUILD_NUMBER_FILE}"
  mkdir -p "$(dirname "$floor_file")"
  printf '%s\n' "$build_number" > "$floor_file"
}

resolve_release_version_and_build() {
  local app_version="${1:-${APP_VERSION:-}}"
  if [ -z "$app_version" ]; then
    echo "resolve_release_version_and_build: APP_VERSION not set" >&2
    return 1
  fi

  local formula build_number floor
  formula=$(compute_build_number_from_version "$app_version")
  floor=$(read_xcode_cloud_build_floor)
  build_number=$formula

  if [ "$formula" -le "$floor" ]; then
    build_number=$((floor + 1))
    app_version=$(version_string_from_build_number "$build_number")
    echo "🍎 Xcode Cloud floor ${floor} — aligned to APP_VERSION=${app_version} BUILD_NUMBER=${build_number}"
  fi

  export APP_VERSION="$app_version"
  export BUILD_NUMBER="$build_number"
}

write_app_version_to_env_files() {
  local app_version="$1"
  local env_file="${2:-${FRONTEND_ENV:-}}"
  local dart_file="${3:-${DART_DEFINES_ENV:-}}"

  if [ -z "$env_file" ]; then
    return 0
  fi

  if [ -f "$env_file" ] && grep -q '^APP_VERSION=' "$env_file" 2>/dev/null; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^APP_VERSION=.*/APP_VERSION=$app_version/" "$env_file"
    else
      sed -i "s/^APP_VERSION=.*/APP_VERSION=$app_version/" "$env_file"
    fi
  else
    echo "APP_VERSION=$app_version" >> "$env_file"
  fi

  if [ -n "$dart_file" ] && [ -f "$dart_file" ]; then
    if grep -q '^APP_VERSION=' "$dart_file" 2>/dev/null; then
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^APP_VERSION=.*/APP_VERSION=$app_version/" "$dart_file"
      else
        sed -i "s/^APP_VERSION=.*/APP_VERSION=$app_version/" "$dart_file"
      fi
    else
      echo "APP_VERSION=$app_version" >> "$dart_file"
    fi
  fi
}

sync_ios_xcode_version() {
  local app_version="${1:-${APP_VERSION:-}}"
  local build_number="${2:-${BUILD_NUMBER:-}}"
  local root="${REPO_ROOT:-}"

  if [ -z "$app_version" ] || [ -z "$build_number" ]; then
    echo "sync_ios_xcode_version: APP_VERSION and BUILD_NUMBER required" >&2
    return 1
  fi

  local pbxproj="$root/flutter_base_05/ios/Runner.xcodeproj/project.pbxproj"
  if [ ! -f "$pbxproj" ]; then
    echo "sync_ios_xcode_version: missing $pbxproj" >&2
    return 1
  fi

  python3 - "$pbxproj" "$app_version" "$build_number" <<'PY'
import re
import sys
from pathlib import Path

pbx_path, marketing_version, build_number = sys.argv[1:4]
text = Path(pbx_path).read_text()
block_re = re.compile(
    r"(\t\t\w+ /\* \w+ \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};)",
    re.DOTALL,
)

def update_runner_block(block: str) -> str:
    if "INFOPLIST_FILE = Runner/Info.plist;" not in block:
        return block
    block = re.sub(
        r"\t\t\t\tMARKETING_VERSION = [^;]+;",
        f"\t\t\t\tMARKETING_VERSION = {marketing_version};",
        block,
    )
    block = re.sub(
        r"\t\t\t\tCURRENT_PROJECT_VERSION = [^;]+;",
        f"\t\t\t\tCURRENT_PROJECT_VERSION = {build_number};",
        block,
    )
    return block

updated = block_re.sub(lambda m: update_runner_block(m.group(1)), text)
Path(pbx_path).write_text(updated)
PY

  write_xcode_cloud_build_floor "$build_number"
  echo "📝 Synced iOS Xcode → MARKETING_VERSION=${app_version}, CURRENT_PROJECT_VERSION=${build_number}"
}

sync_pubspec_version() {
  local app_version="${1:-${APP_VERSION:-}}"
  local build_number="${2:-${BUILD_NUMBER:-}}"
  local root="${REPO_ROOT:-}"

  if [ -z "$app_version" ] || [ -z "$root" ]; then
    echo "sync_pubspec_version: APP_VERSION / REPO_ROOT required" >&2
    return 1
  fi

  local pubspec="$root/flutter_base_05/pubspec.yaml"
  if [ ! -f "$pubspec" ]; then
    echo "sync_pubspec_version: missing $pubspec" >&2
    return 1
  fi

  if [ -z "$build_number" ]; then
    build_number="$(compute_build_number_from_version "$app_version")"
  fi

  local new_line="version: ${app_version}+${build_number}"
  if grep -q '^version:' "$pubspec" 2>/dev/null; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^version:.*/${new_line}/" "$pubspec"
    else
      sed -i "s/^version:.*/${new_line}/" "$pubspec"
    fi
  else
    echo "$new_line" >> "$pubspec"
  fi

  echo "📝 Synced pubspec.yaml → ${app_version}+${build_number}"
  export BUILD_NUMBER="$build_number"
  sync_ios_xcode_version "$app_version" "$build_number"
}

read_pubspec_app_version() {
  local root="${REPO_ROOT:-}"
  local pubspec="$root/flutter_base_05/pubspec.yaml"
  if [ ! -f "$pubspec" ]; then
    echo "read_pubspec_app_version: pubspec not found: $pubspec" >&2
    return 1
  fi
  python3 - "$pubspec" <<'PY'
import re
import sys
from pathlib import Path

for raw in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    m = re.match(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?\s*$", raw.strip())
    if m:
        print(m.group(1))
        break
else:
    raise SystemExit("version line not found in pubspec.yaml")
PY
}

# --- Dart-defines JSON (no AdMob platform overrides) ----------------------------

ios_release_prepare_dart_defines() {
  local env_file="${1:-${DART_DEFINES_ENV:-}}"
  if [ -z "$env_file" ] || [ ! -f "$env_file" ]; then
    echo "ios_release_prepare_dart_defines: env file not found" >&2
    return 1
  fi
  if ! command -v python3 &>/dev/null; then
    echo "ios_release_prepare_dart_defines: python3 required" >&2
    return 1
  fi

  DART_DEF_JSON="$(mktemp "${TMPDIR:-/tmp}/flutter-dart-defines.XXXXXX")" || return 1
  python3 - "$env_file" "$DART_DEF_JSON" <<'PY'
import json
import re
import sys
from pathlib import Path

line_re = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
inp, outp = Path(sys.argv[1]), Path(sys.argv[2])
obj = {}
for raw in inp.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    m = line_re.match(line)
    if not m:
        continue
    key, val = m.group(1), m.group(2)
    if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
        val = val[1:-1]
    obj[key] = val
outp.write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
PY
  export DART_DEF_JSON
  local keycount
  keycount="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1],encoding="utf-8"))))' "$DART_DEF_JSON")"
  echo "📝 Dart-define SSOT: $env_file ($keycount keys → $DART_DEF_JSON)"
}

ios_release_validate_api_url() {
  local json_file="${1:-${DART_DEF_JSON:-}}"
  if [ -z "$json_file" ] || [ ! -f "$json_file" ]; then
    echo "❌ ios_release_validate_api_url: dart-define JSON not found" >&2
    return 1
  fi
  python3 - "$json_file" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
api = (data.get("API_URL") or "").strip().lower()
if not api:
    print("❌ API_URL is missing from dart-defines", file=sys.stderr)
    sys.exit(1)
for token in ("10.0.2.2", "localhost", "127.0.0.1"):
    if token in api:
        print(f"❌ API_URL={data.get('API_URL')!r} is not production (contains {token})", file=sys.stderr)
        sys.exit(1)
print(f"✅ API_URL validated: {data.get('API_URL')}")
PY
}

ios_release_assert_generated_dart_defines() {
  local generated_xcconfig="${1:-}"
  if [ -z "$generated_xcconfig" ] || [ ! -f "$generated_xcconfig" ]; then
    echo "❌ ios_release_assert_generated_dart_defines: Generated.xcconfig not found" >&2
    return 1
  fi
  python3 - "$generated_xcconfig" <<'PY'
import base64
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
m = re.search(r"^DART_DEFINES=(.*)$", text, re.M)
if not m or not m.group(1).strip():
    print("❌ Generated.xcconfig DART_DEFINES is empty", file=sys.stderr)
    sys.exit(1)
found_api = False
for part in m.group(1).split(","):
    part = part.strip()
    if not part:
        continue
    try:
        decoded = base64.b64decode(part).decode("utf-8")
    except Exception:
        continue
    if decoded.startswith("API_URL="):
        found_api = True
        print(f"✅ Generated.xcconfig includes {decoded.split('=', 1)[0]}")
        break
if not found_api:
    print("❌ Generated.xcconfig DART_DEFINES does not include API_URL", file=sys.stderr)
    sys.exit(1)
PY
}
