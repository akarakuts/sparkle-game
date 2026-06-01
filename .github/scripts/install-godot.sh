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

if [[ ! -f "$TPL_ROOT/android_debug.apk" ]]; then
  TPZ="Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_export_templates.tpz"
  wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/${TPZ}"
  unzip -qo "$TPZ" -d "$TPL_ROOT"
fi

echo "Export templates: $TPL_ROOT"
