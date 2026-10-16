#!/usr/bin/env bash
# Runs the headless test suite. Usage: GODOT=/path/to/godot ./tools/run_tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --fixed-fps 60 --path . --script res://tests/run_tests.gd
