#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER_EXEC="$ROOT_DIR/.build/Spill.app/Contents/Applications/Spill Token Dashboard.app/Contents/MacOS/Spill"
SMOKE_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/spill-token-dashboard-render-smoke.XXXXXX")"
LOG_FILE="$SMOKE_TMP_DIR/render.log"
RENDER_BUDGET_MS=1500
MINIMUM_WIDTH=1060
MINIMUM_HEIGHT=640
PID=""

cleanup() {
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        wait "$PID" 2>/dev/null || true
    fi
    rm -rf "$SMOKE_TMP_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/build-app.sh"

if [[ ! -x "$HELPER_EXEC" ]]; then
    echo "FAIL: Spill token dashboard helper executable is missing."
    exit 1
fi

SPILL_SMOKE_TEST=1 \
SPILL_TOKEN_DASHBOARD_STANDALONE=1 \
SPILL_TOKEN_DASHBOARD_RENDER_SMOKE=1 \
SPILL_SMOKE_TEST_EXIT_AFTER=2.0 \
SPILL_TOKEN_USAGE_EVENTS_FILE="$SMOKE_TMP_DIR/events.json" \
SPILL_TOKEN_USAGE_INBOX_DIR="$SMOKE_TMP_DIR/events-inbox" \
"$HELPER_EXEC" >"$LOG_FILE" 2>&1 &
PID="$!"

deadline=$((SECONDS + 10))
while kill -0 "$PID" 2>/dev/null; do
    if (( SECONDS >= deadline )); then
        echo "FAIL: Spill token dashboard visible render smoke timed out."
        cat "$LOG_FILE"
        exit 1
    fi
    sleep 0.2
done

if ! wait "$PID"; then
    echo "FAIL: Spill token dashboard visible render smoke exited with a non-zero status."
    cat "$LOG_FILE"
    exit 1
fi
PID=""

if ! grep -q "SPILL_TOKEN_DASHBOARD_RENDER_READY" "$LOG_FILE"; then
    echo "FAIL: Spill token dashboard did not report a visible render."
    cat "$LOG_FILE"
    exit 1
fi

elapsed_ms="$(sed -nE 's/.*elapsed_ms=([0-9]+).*/\1/p' "$LOG_FILE" | tail -n 1)"
width="$(sed -nE 's/.*width=([0-9]+).*/\1/p' "$LOG_FILE" | tail -n 1)"
height="$(sed -nE 's/.*height=([0-9]+).*/\1/p' "$LOG_FILE" | tail -n 1)"

if [[ ! "$elapsed_ms" =~ ^[0-9]+$ ]] || [[ ! "$width" =~ ^[0-9]+$ ]] || [[ ! "$height" =~ ^[0-9]+$ ]]; then
    echo "FAIL: Spill token dashboard render metrics were malformed."
    cat "$LOG_FILE"
    exit 1
fi

if (( elapsed_ms >= RENDER_BUDGET_MS )); then
    echo "FAIL: Visible token dashboard render took ${elapsed_ms}ms (budget: <${RENDER_BUDGET_MS}ms)."
    exit 1
fi

if (( width < MINIMUM_WIDTH || height < MINIMUM_HEIGHT )); then
    echo "FAIL: Visible token dashboard content was ${width}x${height}; expected at least ${MINIMUM_WIDTH}x${MINIMUM_HEIGHT}."
    exit 1
fi

echo "OK: Visible token dashboard rendered in ${elapsed_ms}ms at ${width}x${height} (budget: <${RENDER_BUDGET_MS}ms)."
