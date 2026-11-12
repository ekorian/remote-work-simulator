#!/usr/bin/env bash
# Render scripted screenshots offscreen:  tools/shots.sh <scene> [out_dir]
cd "$(dirname "$0")/.."
GODOT="${GODOT:-./.tools/godot}"
SCENE="${1:-world}"
OUT="${2:-/tmp/rws_shots}"
mkdir -p "$OUT"
timeout "${TIMEOUT:-150}" xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" --path . --rendering-driver vulkan --resolution "${RES:-1600x900}" \
  -- --shots="$OUT" --scene="$SCENE" $EXTRA 2>&1 \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | grep -vE '^\s*$|_create_xic|DRI3|Xorg|wd.xic|Godot Engine|Vulkan 1' | head -${LINES_MAX:-30}
