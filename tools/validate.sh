#!/usr/bin/env bash
# Headless validation: the checked equivalent of `godot --headless --path . --quit`.
# A clean exit code alone proves little, so this also verifies that
#   1. the project imports and every script compiles,
#   2. the main scene boots and runs 120 frames with no error in the log,
#   3. every scene and resource loads and every gameplay invariant in
#      tests/rules_test holds.
# Exits non-zero on any failure.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-./.tools/godot}"
[ -x "$GODOT" ] || GODOT="$(command -v godot4 || command -v godot)"
[ -n "$GODOT" ] || { echo "Godot not found. Run tools/setup_godot.sh or set GODOT=..."; exit 2; }
clean() { sed 's/\x1b\[[0-9;]*m//g' | grep -vE '^\s*$|Godot Engine'; }
FAIL=0
echo "== import and compile"
OUT="$(GODOT="$GODOT" ./tools/check.sh)"; echo "   $OUT"
echo "$OUT" | grep -q "failed: 0" || FAIL=1
echo "== boot the main scene (120 frames)"
RAW="$("$GODOT" --headless --path . --quit-after 120 2>&1)"; RC=$?
LOG="$(echo "$RAW" | clean)"
if [ $RC -ne 0 ] || echo "$LOG" | grep -qE 'ERROR|WARNING|Parse Error'; then
  echo "$LOG" | head -20; FAIL=1
else
  echo "   clean start, clean shutdown"
fi
echo "== scenes, resources and gameplay invariants"
timeout "${TEST_TIMEOUT:-600}" "$GODOT" --headless --path . res://tests/rules_test.tscn 2>&1 | clean | grep -E '^==|FAIL|checks|RESULT' | sed 's/^/   /'
[ "${PIPESTATUS[0]}" -eq 0 ] || FAIL=1
[ "$FAIL" -eq 0 ] && echo "VALIDATION PASSED" || echo "VALIDATION FAILED"
exit $FAIL
