#!/usr/bin/env bash
# Runs the headless test scenes. Used by Jenkins and by .githooks/pre-push.
#
#   tools/run_tests.sh            every tests/*.tscn
#   tools/run_tests.sh --quick    only the scenes in QUICK_TESTS (what the pre-push hook runs)
#
# A scene fails if it exits non-zero, runs past its timeout, or prints "SCRIPT ERROR". The last
# one matters: a script that does not compile leaves the scene running with exit code 0 (or
# hanging), so the exit code alone lets a broken build through.
#
# Godot is taken from $GODOT, then from PATH, then from C:\Godot (the Windows dev machine).
set -u

QUICK_TESTS="test_runner test_elevator_alignment"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"

cd "$(dirname "$0")/.."

GODOT_BIN="${GODOT:-}"
if [ -z "$GODOT_BIN" ]; then
    if command -v godot >/dev/null 2>&1; then
        GODOT_BIN="godot"
    else
        GODOT_BIN="$(ls /c/Godot/Godot_v*_win64_console.exe 2>/dev/null | head -n 1)"
    fi
fi
if [ -z "$GODOT_BIN" ]; then
    echo "run_tests: Godot not found - set GODOT to the editor binary" >&2
    exit 2
fi

LOG_DIR="${TEST_LOG_DIR:-build/test_logs}"
mkdir -p "$LOG_DIR"

if [ "${1:-}" = "--quick" ]; then
    scenes=""
    for name in $QUICK_TESTS; do scenes="$scenes tests/$name.tscn"; done
else
    scenes="$(ls tests/*.tscn)"
fi

# A fresh checkout has no .godot/ - the scenes cannot load anything until it is imported.
if [ ! -d .godot/imported ]; then
    echo "run_tests: importing the project first..."
    timeout 600 "$GODOT_BIN" --headless --path . --editor --quit > "$LOG_DIR/import.log" 2>&1 || true
fi

failed=""
for scene in $scenes; do
    name="$(basename "$scene" .tscn)"
    log="$LOG_DIR/$name.log"
    timeout "$TEST_TIMEOUT" "$GODOT_BIN" --headless --path . "$scene" > "$log" 2>&1
    code=$?
    errors="$(grep -c 'SCRIPT ERROR' "$log")"
    if [ "$code" -eq 124 ]; then
        echo "FAIL  $name  (timed out after ${TEST_TIMEOUT}s)"
    elif [ "$code" -ne 0 ]; then
        echo "FAIL  $name  (exit code $code)"
    elif [ "$errors" -ne 0 ]; then
        echo "FAIL  $name  ($errors script error(s))"
    else
        echo "ok    $name"
        continue
    fi
    failed="$failed $name"
    grep -A 3 'SCRIPT ERROR' "$log" | head -n 40
    grep 'FAIL' "$log" | head -n 20
done

if [ -n "$failed" ]; then
    echo "run_tests: FAILED:$failed  (logs in $LOG_DIR)"
    exit 1
fi
echo "run_tests: all passed"
