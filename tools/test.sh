#!/usr/bin/env bash
# Run every automated check. Exits non-zero if anything fails.
#   tools/test.sh            everything
#   RUNS=24 tools/test.sh    more full-week runs per bot and difficulty
cd "$(dirname "$0")/.."
GODOT="${GODOT:-./.tools/godot}"
clean() { sed 's/\x1b\[[0-9;]*m//g' | grep -vE '^\s*$|Godot Engine|ObjectDB instances were leaked|cleanup \(core|still in use at exit|clear \(core'; }
FAIL=0
echo "### parse: every script compiles"
OUT="$(./tools/check.sh)"; echo "$OUT"
echo "$OUT" | grep -q "failed: 0" || FAIL=1
echo "### startup: the main scene boots headless with no errors"
RAW="$("$GODOT" --headless --path . --quit-after 120 2>&1)"; RC=$?
BOOT="$(echo "$RAW" | sed 's/\x1b\[[0-9;]*m//g' | grep -vE '^\s*$|Godot Engine')"
if [ $RC -ne 0 ] || echo "$BOOT" | grep -qE 'ERROR|WARNING|Parse Error'; then echo "$BOOT" | head -20; FAIL=1; else echo "ok"; fi
# A test scene whose script fails to parse loads without it and never quits,
# so every scene runs under a time limit (TEST_TIMEOUT seconds, default 900).
for T in rules_test run_test world_test; do
  echo "### $T"
  timeout "${TEST_TIMEOUT:-900}" "$GODOT" --headless --path . "res://tests/$T.tscn" -- --runs="${RUNS:-12}" 2>&1 | clean
  RC=${PIPESTATUS[0]}
  [ "$RC" -eq 124 ] && echo "TIMED OUT: $T did not finish (a parse error in the test script? run tools/check.sh)"
  [ "$RC" -eq 0 ] || FAIL=1
done
[ "$FAIL" -eq 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $FAIL
