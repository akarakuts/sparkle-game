#!/usr/bin/env bash
# Keystore + keystore.properties for local Gradle; export_credentials.cfg for Godot release presets.
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$ROOT"

KEYSTORE_B64="${RELEASE_KEYSTORE_BASE64:-}"
STORE_PASSWORD="${RELEASE_STORE_PASSWORD:-}"
KEY_ALIAS="${RELEASE_KEY_ALIAS:-}"
KEY_PASSWORD="${RELEASE_KEY_PASSWORD:-}"

if [[ -z "$KEYSTORE_B64" || -z "$STORE_PASSWORD" || -z "$KEY_ALIAS" || -z "$KEY_PASSWORD" ]]; then
  echo '::error::Set secrets: RELEASE_KEYSTORE_BASE64, RELEASE_STORE_PASSWORD, RELEASE_KEY_ALIAS, RELEASE_KEY_PASSWORD' >&2
  exit 1
fi

echo "$KEYSTORE_B64" | base64 -d > "$ROOT/upload-keystore.jks"

export ROOT STORE_PASSWORD="$STORE_PASSWORD" KEY_ALIAS="$KEY_ALIAS" KEY_PASSWORD="$KEY_PASSWORD"
python3 <<'PY'
import os
from pathlib import Path

def escape_java_properties_value(s: str) -> str:
    out = []
    for c in s:
        if c == "\\":
            out.append("\\\\")
        elif c == "\n":
            out.append("\\n")
        elif c == "\r":
            out.append("\\r")
        elif c == "\t":
            out.append("\\t")
        elif c == ":":
            out.append("\\:")
        elif c == "=":
            out.append("\\=")
        else:
            out.append(c)
    return "".join(out)

root = Path(os.environ["ROOT"])
lines = [
    "storeFile=upload-keystore.jks",
    "storePassword=" + escape_java_properties_value(os.environ["STORE_PASSWORD"]),
    "keyAlias=" + escape_java_properties_value(os.environ["KEY_ALIAS"]),
    "keyPassword=" + escape_java_properties_value(os.environ["KEY_PASSWORD"]),
]
(root / "keystore.properties").write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

KEYSTORE="$ROOT/upload-keystore.jks"
mkdir -p "$ROOT/.godot"
cat > "$ROOT/.godot/export_credentials.cfg" <<EOF
[preset.1.options]

keystore/release="${KEYSTORE}"
keystore/release_user="${KEY_ALIAS}"
keystore/release_password="${STORE_PASSWORD}"

[preset.2.options]

keystore/release="${KEYSTORE}"
keystore/release_user="${KEY_ALIAS}"
keystore/release_password="${STORE_PASSWORD}"
EOF
chmod 600 "$ROOT/.godot/export_credentials.cfg"
echo "OK: signing prepared for Godot export"
