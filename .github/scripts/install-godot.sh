#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.6.3}"
GODOT_RELEASE="${GODOT_RELEASE:-stable}"
GODOT_FOLDER="${GODOT_VERSION}.${GODOT_RELEASE}"

TPL_ROOT="${HOME}/.local/share/godot/export_templates/${GODOT_FOLDER}"
mkdir -p "$TPL_ROOT"

if ! command -v godot >/dev/null 2>&1; then
  GODOT_ZIP="Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64.zip"
  wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/${GODOT_ZIP}"
  unzip -q "$GODOT_ZIP"
  BIN="Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64"
  chmod +x "$BIN"
  sudo mv "$BIN" /usr/local/bin/godot
fi

godot --version

if [[ ! -f "$TPL_ROOT/android_source.zip" ]]; then
  TPZ="Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_export_templates.tpz"
  wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/${TPZ}"
  TMP="$(mktemp -d)"
  unzip -qo "$TPZ" -d "$TMP"
  rm -f "$TPZ"
  # TPZ may unpack flat or one level down — normalize into TPL_ROOT.
  if [[ -f "$TMP/android_source.zip" ]]; then
    cp -a "$TMP"/. "$TPL_ROOT"/
  else
    SRC="$(find "$TMP" -name android_source.zip -print -quit | xargs dirname)"
    if [[ -z "${SRC:-}" || ! -f "$SRC/android_source.zip" ]]; then
      echo "android_source.zip not found after extracting export templates" >&2
      find "$TMP" -maxdepth 3 -type f | head -20 >&2
      exit 1
    fi
    cp -a "$SRC"/. "$TPL_ROOT"/
  fi
  rm -rf "$TMP"
fi

if [[ ! -f "$TPL_ROOT/android_source.zip" ]]; then
  echo "Missing $TPL_ROOT/android_source.zip after install" >&2
  ls -la "$TPL_ROOT" >&2 || true
  exit 1
fi

echo "Export templates OK: $TPL_ROOT (android_source.zip present)"
