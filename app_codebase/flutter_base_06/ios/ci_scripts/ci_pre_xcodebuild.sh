#!/bin/bash
# Xcode Cloud pre-xcodebuild hook.
# Copy entire ci_scripts/ dir to flutter_app/ios/ci_scripts/
set -euo pipefail

echo "===> Xcode Cloud pre-xcodebuild start"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FLUTTER_APP_DIR="$(cd "${IOS_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${FLUTTER_APP_DIR}/.." && pwd)"

export REPO_ROOT FLUTTER_APP_DIR IOS_DIR

if [ ! -f "${FLUTTER_APP_DIR}/pubspec.yaml" ]; then
  echo "ERROR: pubspec.yaml not found at ${FLUTTER_APP_DIR}"
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  export PATH="${HOME}/flutter/bin:${PATH}"
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter not found on PATH"
  exit 1
fi

# shellcheck source=ios_release_prebuild.sh
source "$SCRIPT_DIR/ios_release_prebuild.sh"
# shellcheck source=pre_build_config_adjust_ios.sh
source "$SCRIPT_DIR/pre_build_config_adjust_ios.sh"

DART_DEF_JSON=""
trap 'rm -f "${DART_DEF_JSON:-}"' EXIT

xcode_cloud_materialize_env

APP_VERSION="$(read_pubspec_app_version)"
export APP_VERSION
echo "📦 pubspec APP_VERSION=$APP_VERSION"

resolve_release_version_and_build "$APP_VERSION"
write_app_version_to_env_files "$APP_VERSION"
echo "🔢 Using build-name=$APP_VERSION build-number=$BUILD_NUMBER"
sync_pubspec_version "$APP_VERSION" "$BUILD_NUMBER"

pre_build_config_adjust_ios

ios_release_prepare_dart_defines "$DART_DEFINES_ENV"
ios_release_validate_api_url "$DART_DEF_JSON"

cd "$FLUTTER_APP_DIR"
flutter build ios --config-only --no-codesign \
  --build-name="$APP_VERSION" \
  --build-number="$BUILD_NUMBER" \
  --dart-define-from-file="$DART_DEF_JSON"

ios_release_assert_generated_dart_defines "${FLUTTER_APP_DIR}/ios/Flutter/Generated.xcconfig"

echo "===> Pre-xcodebuild complete (dart-defines in Generated.xcconfig)"
