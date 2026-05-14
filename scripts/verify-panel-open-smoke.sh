#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXEC="$ROOT_DIR/.build/Spill.app/Contents/MacOS/Spill"
LOG_FILE="${TMPDIR:-/tmp}/spill-panel-open-smoke.log"
PID=""

cleanup() {
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        wait "$PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

"$ROOT_DIR/scripts/build-app.sh"

rm -f "$LOG_FILE"

SPILL_SMOKE_TEST=1 SPILL_SMOKE_OPEN_PANEL=1 SPILL_SMOKE_TEST_EXIT_AFTER=1.0 "$APP_EXEC" >"$LOG_FILE" 2>&1 &
PID="$!"

deadline=$((SECONDS + 8))
while kill -0 "$PID" 2>/dev/null; do
    if (( SECONDS >= deadline )); then
        echo "FAIL: Spill panel-open smoke test timed out."
        cat "$LOG_FILE"
        exit 1
    fi

    sleep 0.2
done

if ! wait "$PID"; then
    echo "FAIL: Spill exited with a non-zero status during panel-open smoke."
    cat "$LOG_FILE"
    exit 1
fi
PID=""

if ! grep -q "SPILL_SMOKE_READY" "$LOG_FILE"; then
    echo "FAIL: Spill did not report smoke readiness."
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_PANEL_SMOKE_VISIBLE" "$LOG_FILE"; then
    echo "FAIL: Spill did not report panel visibility."
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_SMOKE_EXIT" "$LOG_FILE"; then
    echo "FAIL: Spill did not report smoke shutdown."
    cat "$LOG_FILE"
    exit 1
fi

echo "OK: Spill panel-open smoke test passed."
