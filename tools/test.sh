#!/usr/bin/env bash
# Run every automated check: parse, rules + balance, and the 3D world walk.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-./.tools/godot}"
clean() { sed 's/\x1b\[[0-9;]*m//g' | grep -vE '^\s*$|Godot Engine'; }
echo "### parse"
./tools/check.sh
echo "### rules and balance"
"$GODOT" --headless --path . res://tests/sim_test.tscn -- --runs="${RUNS:-16}" 2>&1 | clean
A=${PIPESTATUS[0]}
echo "### world"
"$GODOT" --headless --path . res://tests/world_test.tscn 2>&1 | clean
B=${PIPESTATUS[0]}
[ "$A" -eq 0 ] && [ "$B" -eq 0 ]
