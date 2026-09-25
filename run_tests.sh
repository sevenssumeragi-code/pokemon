#!/usr/bin/env bash
# Run the headless unit test suite. Optional arg: substring filter on test file name.
# Fails if any SCRIPT ERROR / ERROR appears in Godot's output (script errors don't stop Godot).
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
OUT=$("$GODOT" --headless --path . -s tests/test_runner.gd -- "${1:-}" 2>&1 | grep -v "^Godot Engine")
echo "$OUT"
STATUS=0
echo "$OUT" | grep -q "failed, " || STATUS=1
echo "$OUT" | grep -v "resources still in use" | grep -qE "SCRIPT ERROR|^ERROR|USER ERROR" && STATUS=1
echo "$OUT" | grep -qE "=== .* 0 failed" || STATUS=1
# UI smoke (headless auto-play through the battle screen)
for D in 0 1; do
UI=$(UI_SMOKE_DOUBLES=$D "$GODOT" --headless --path . -s tests/ui_smoke.gd 2>&1 | grep -v "^Godot Engine")
echo "$UI" | grep -E "UI_SMOKE|SCRIPT ERROR" | sed "s/^/[doubles=$D] /"
echo "$UI" | grep -q "UI_SMOKE_OK" || STATUS=1
echo "$UI" | grep -qE "SCRIPT ERROR" && STATUS=1
done
exit $STATUS
