#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
if ! command -v "$godot_bin" >/dev/null 2>&1; then
    printf 'Godot 4.4 or later is required. Set GODOT_BIN to your executable.\n' >&2
    exit 1
fi
"$godot_bin" --headless --path "$project_dir" --editor --import
exec "$godot_bin" --path "$project_dir" "$@"
