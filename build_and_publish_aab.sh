#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile"
PUBLIC_AAB_DIR="$ROOT_DIR/backend/public/app"
PUBLIC_AAB_PATH="$PUBLIC_AAB_DIR/studio59.aab"
BUILD_USER="flutter"

run_as_build_user() {
  if [ "$(id -u)" -eq 0 ]; then
    runuser -u "$BUILD_USER" -- bash -lc "$1"
  else
    bash -lc "$1"
  fi
}

increment_pubspec_version() {
  local pubspec="$MOBILE_DIR/pubspec.yaml"
  if [ ! -f "$pubspec" ]; then
    echo "pubspec.yaml not found at $pubspec" >&2
    exit 1
  fi
  local current
  if command -v rg >/dev/null 2>&1; then
    current="$(rg -N '^version:' "$pubspec" | head -n1 | awk '{print $2}')"
  else
    current="$(grep -E '^version:' "$pubspec" | head -n1 | awk '{print $2}')"
  fi
  if [ -z "$current" ]; then
    echo "No version found in pubspec.yaml" >&2
    exit 1
  fi
  local base build
  if [[ "$current" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
    base="${BASH_REMATCH[1]}"
    build="${BASH_REMATCH[2]}"
  elif [[ "$current" =~ ^([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    base="${BASH_REMATCH[1]}"
    build="0"
  else
    echo "Unsupported version format in pubspec.yaml: $current" >&2
    exit 1
  fi
  local next_build=$((build + 1))
  local next_version="${base}+${next_build}"
  perl -0777 -i -pe "s/^version:\\s.*$/version: ${next_version}/m" "$pubspec"
  echo "Bumped pubspec.yaml version: $current -> $next_version"
}

EXTRA_FLAGS="${EXTRA_FLAGS:-}"
CLEAN_BUILD="${CLEAN_BUILD:-0}"

chmod -R u+rwX "$MOBILE_DIR" || true
chown -R "$BUILD_USER":"$BUILD_USER" "$MOBILE_DIR" || true
rm -rf "$MOBILE_DIR/.dart_tool" \
  "$MOBILE_DIR/linux/flutter/ephemeral/.plugin_symlinks" \
  "$MOBILE_DIR/windows/flutter/ephemeral/.plugin_symlinks" \
  "$MOBILE_DIR/android/.gradle" || true

increment_pubspec_version

export MOBILE_DIR CLEAN_BUILD EXTRA_FLAGS
run_as_build_user 'source /etc/profile.d/flutter.sh >/dev/null 2>&1 || true; source /etc/profile.d/android.sh >/dev/null 2>&1 || true; cd "$MOBILE_DIR"; export GRADLE_OPTS="-Dorg.gradle.daemon=false"; if [ "$CLEAN_BUILD" = "1" ]; then flutter clean; if command -v watchman >/dev/null 2>&1; then watchman watch-del-all || true; fi; fi; flutter pub get; flutter build appbundle --release $EXTRA_FLAGS'

mkdir -p "$PUBLIC_AAB_DIR"
cp "$MOBILE_DIR/build/app/outputs/bundle/release/app-release.aab" "$PUBLIC_AAB_PATH"

chown "$BUILD_USER":"$BUILD_USER" "$PUBLIC_AAB_PATH" || true

echo "AAB publicado em: $PUBLIC_AAB_PATH"
