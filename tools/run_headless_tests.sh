#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT_DIR/.tools/Godot.app/Contents/MacOS/Godot}"

"$GODOT_BIN" --path "$ROOT_DIR" --headless -s tools/test_runner.gd
