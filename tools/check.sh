#!/usr/bin/env bash
# Parse-check every GDScript file. Prints errors with file:line.
#   tools/check.sh           re-import (refreshes the class_name cache), then check
#   tools/check.sh --fast    skip the re-import
cd "$(dirname "$0")/.."
GODOT="${GODOT:-./.tools/godot}"
if [ "$1" != "--fast" ]; then
  "$GODOT" --headless --path . --import >/dev/null 2>&1
fi
"$GODOT" --headless --path . res://tests/load_all.tscn 2>&1 \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | grep -E 'Parse Error|Compile Error|at: GDScript::reload|^BAD|^scripts:' \
  | grep -v 'Failed to compile depended' | paste - - 2>/dev/null | sed 's/[[:space:]]\+at: GDScript::reload/  @/' | sort -u | head -40
