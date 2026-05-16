#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXEC="$ROOT_DIR/.build/Spill.app/Contents/MacOS/Spill"
LOG_FILE="${TMPDIR:-/tmp}/spill-panel-layout-smoke.log"
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

SPILL_SMOKE_TEST=1 \
SPILL_SMOKE_OPEN_PANEL=1 \
SPILL_SMOKE_VALIDATE_PANEL_LAYOUT=1 \
SPILL_SMOKE_TEST_EXIT_AFTER=1.2 \
"$APP_EXEC" >"$LOG_FILE" 2>&1 &
PID="$!"

deadline=$((SECONDS + 8))
while kill -0 "$PID" 2>/dev/null; do
    if (( SECONDS >= deadline )); then
        echo "FAIL: Spill panel layout smoke test timed out."
        cat "$LOG_FILE"
        exit 1
    fi

    sleep 0.2
done

if ! wait "$PID"; then
    echo "FAIL: Spill exited with a non-zero status during panel layout smoke."
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

if ! grep -q "SPILL_PANEL_LAYOUT " "$LOG_FILE"; then
    echo "FAIL: Spill did not report panel layout diagnostics."
    cat "$LOG_FILE"
    exit 1
fi

if grep -q "SPILL_PANEL_LAYOUT_FAIL" "$LOG_FILE"; then
    echo "FAIL: Spill panel layout validation failed."
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_PANEL_LAYOUT_OK" "$LOG_FILE"; then
    echo "FAIL: Spill did not report panel layout success."
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_PANEL_CONTENT " "$LOG_FILE"; then
    echo "FAIL: Spill did not report panel content diagnostics."
    cat "$LOG_FILE"
    exit 1
fi

if grep -q "SPILL_PANEL_CONTENT_FAIL" "$LOG_FILE"; then
    echo "FAIL: Spill panel content validation failed."
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_PANEL_CONTENT_OK" "$LOG_FILE"; then
    echo "FAIL: Spill did not report panel content success."
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_PANEL_ACCESSIBILITY " "$LOG_FILE"; then
    echo "FAIL: Spill did not report panel accessibility diagnostics."
    cat "$LOG_FILE"
    exit 1
fi

if grep -q "SPILL_PANEL_ACCESSIBILITY_FAIL" "$LOG_FILE"; then
    echo "FAIL: Spill panel accessibility validation failed."
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_PANEL_ACCESSIBILITY_OK" "$LOG_FILE"; then
    echo "FAIL: Spill did not report panel accessibility success."
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_SMOKE_EXIT" "$LOG_FILE"; then
    echo "FAIL: Spill did not report smoke shutdown."
    cat "$LOG_FILE"
    exit 1
fi

echo "OK: Spill panel layout smoke test passed."
