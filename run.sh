#!/usr/bin/env bash
# Run the game from source. Uses the project-local Godot if present
# (tools/setup_godot.sh), otherwise whatever `godot` is on PATH.
cd "$(dirname "$0")"
GODOT="${GODOT:-}"
if [ -z "$GODOT" ]; then
  if [ -x ./.tools/godot ]; then GODOT=./.tools/godot; else GODOT="$(command -v godot4 || command -v godot)"; fi
fi
if [ -z "$GODOT" ]; then
  echo "Godot 4.7+ not found. Run tools/setup_godot.sh or set GODOT=/path/to/godot." >&2
  exit 1
fi
[ -d .godot ] || "$GODOT" --headless --path . --import >/dev/null 2>&1
exec "$GODOT" --path . "$@"
