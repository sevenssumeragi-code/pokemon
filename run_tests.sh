#!/usr/bin/env bash
# Run the headless unit test suite. Optional arg: substring filter on test file name.
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
# Rebuild the global script class cache so class_name resolves headless.
"$GODOT" --headless --path . --import >/dev/null 2>&1
if [ $# -gt 0 ]; then
  "$GODOT" --headless --path . -s tests/test_runner.gd -- "$1"
else
  "$GODOT" --headless --path . -s tests/test_runner.gd
fi
