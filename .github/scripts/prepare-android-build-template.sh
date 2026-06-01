#!/usr/bin/env bash
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}"
GODOT_VERSION="${GODOT_VERSION:-4.6.3}"
GODOT_RELEASE="${GODOT_RELEASE:-stable}"
GODOT_FOLDER="${GODOT_VERSION}.${GODOT_RELEASE}"

TPL_ROOT="${HOME}/.local/share/godot/export_templates/${GODOT_FOLDER}"
ANDROID_BUILD="$ROOT/android/build"
ANDROID_SOURCE="$TPL_ROOT/android_source.zip"

[[ -f "$ANDROID_SOURCE" ]] || { echo "Missing $ANDROID_SOURCE" >&2; exit 1; }

rm -rf "$ANDROID_BUILD"
mkdir -p "$ANDROID_BUILD"
unzip -qo "$ANDROID_SOURCE" -d "$ANDROID_BUILD"
echo "$GODOT_FOLDER" > "$ROOT/android/.build_version"

# Gradle staging clean (same as rustore clean-android-export-staging.sh).
rm -rf "$ANDROID_BUILD/build"
rm -rf "$ANDROID_BUILD/assetPackInstallTime/src/main/assets"
mkdir -p "$ANDROID_BUILD/assetPackInstallTime/src/main/assets"
find "$ANDROID_BUILD/res" -name '*.import' -delete 2>/dev/null || true
: > "$ANDROID_BUILD/.gdignore"

echo "OK: $ANDROID_BUILD"
