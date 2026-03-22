#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile"
PUBLIC_APK_DIR="$ROOT_DIR/backend/public/app"
PUBLIC_APK_PATH="$PUBLIC_APK_DIR/studio59.apk"
BUILD_USER="flutter"

run_as_build_user() {
  if [ "$(id -u)" -eq 0 ]; then
    runuser -u "$BUILD_USER" -- bash -lc "$1"
  else
    bash -lc "$1"
  fi
}

EXTRA_FLAGS="${EXTRA_FLAGS:-}"
CLEAN_BUILD="${CLEAN_BUILD:-0}"

export MOBILE_DIR CLEAN_BUILD EXTRA_FLAGS
run_as_build_user 'source /etc/profile.d/flutter.sh >/dev/null 2>&1 || true; source /etc/profile.d/android.sh >/dev/null 2>&1 || true; cd "$MOBILE_DIR"; if [ "$CLEAN_BUILD" = "1" ]; then flutter clean; if command -v watchman >/dev/null 2>&1; then watchman watch-del-all || true; fi; fi; flutter pub get; flutter build apk --release $EXTRA_FLAGS'

mkdir -p "$PUBLIC_APK_DIR"
cp "$MOBILE_DIR/build/app/outputs/flutter-apk/app-release.apk" "$PUBLIC_APK_PATH"

chown "$BUILD_USER":"$BUILD_USER" "$PUBLIC_APK_PATH" || true

echo "APK publicado em: $PUBLIC_APK_PATH"
