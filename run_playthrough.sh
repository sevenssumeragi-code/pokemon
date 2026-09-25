#!/usr/bin/env bash
# Headless story playthrough (new game -> ending). Takes several minutes.
cd "$(dirname "$0")"
godot --headless --path . --import >/dev/null 2>&1
godot --headless --path . -s tests/rpg_playthrough.gd 2>&1 | grep --line-buffered -v "Godot Engine\|resources still\|resource.cpp\|ObjectDB\|object.cpp\|anchors\|set_deferred\|_set_size" | grep --line-buffered -v "^$"
