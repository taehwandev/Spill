#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXEC="$ROOT_DIR/.build/Spill.app/Contents/MacOS/Spill"
HELPER_EXEC="$ROOT_DIR/.build/Spill.app/Contents/Applications/Spill Token Dashboard.app/Contents/MacOS/Spill"
APP_RESOURCE_BUNDLE="$ROOT_DIR/.build/Spill.app/Contents/Resources/Spill_Spill.bundle"
HELPER_RESOURCE_BUNDLE="$ROOT_DIR/.build/Spill.app/Contents/Applications/Spill Token Dashboard.app/Contents/Resources/Spill_Spill.bundle"
LOG_FILE="${TMPDIR:-/tmp}/spill-runtime-smoke.log"
HELPER_LOG_FILE="${TMPDIR:-/tmp}/spill-token-dashboard-runtime-smoke.log"
HELPER_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/spill-token-dashboard-smoke.XXXXXX")"
PID=""

cleanup() {
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        wait "$PID" 2>/dev/null || true
    fi
    rm -rf "$HELPER_TMP_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/build-app.sh"

if [[ ! -d "$APP_RESOURCE_BUNDLE" ]]; then
    echo "FAIL: Spill SwiftPM resource bundle is missing from app resources."
    exit 1
fi

if [[ ! -d "$HELPER_RESOURCE_BUNDLE" ]]; then
    echo "FAIL: Spill token dashboard SwiftPM resource bundle is missing from helper app resources."
    exit 1
fi

rm -f "$LOG_FILE"
rm -f "$HELPER_LOG_FILE"

SPILL_SMOKE_TEST=1 SPILL_SMOKE_TEST_EXIT_AFTER=1.0 "$APP_EXEC" >"$LOG_FILE" 2>&1 &
PID="$!"

deadline=$((SECONDS + 8))
while kill -0 "$PID" 2>/dev/null; do
    if (( SECONDS >= deadline )); then
        echo "FAIL: Spill runtime smoke test timed out."
        cat "$LOG_FILE"
        exit 1
    fi

    sleep 0.2
done

if ! wait "$PID"; then
    echo "FAIL: Spill exited with a non-zero status."
    cat "$LOG_FILE"
    exit 1
fi
PID=""

if ! grep -q "SPILL_SMOKE_READY" "$LOG_FILE"; then
    echo "FAIL: Spill did not report smoke readiness."
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_SMOKE_EXIT" "$LOG_FILE"; then
    echo "FAIL: Spill did not report smoke shutdown."
    cat "$LOG_FILE"
    exit 1
fi

if [[ ! -x "$HELPER_EXEC" ]]; then
    echo "FAIL: Spill token dashboard helper executable is missing."
    exit 1
fi

SPILL_SMOKE_TEST=1 \
SPILL_TOKEN_DASHBOARD_STANDALONE=1 \
SPILL_SMOKE_TEST_EXIT_AFTER=1.0 \
SPILL_TOKEN_USAGE_EVENTS_FILE="$HELPER_TMP_DIR/events.json" \
SPILL_TOKEN_USAGE_INBOX_DIR="$HELPER_TMP_DIR/events-inbox" \
"$HELPER_EXEC" >"$HELPER_LOG_FILE" 2>&1 &
PID="$!"

deadline=$((SECONDS + 8))
while kill -0 "$PID" 2>/dev/null; do
    if (( SECONDS >= deadline )); then
        echo "FAIL: Spill token dashboard helper smoke test timed out."
        cat "$HELPER_LOG_FILE"
        exit 1
    fi

    sleep 0.2
done

if ! wait "$PID"; then
    echo "FAIL: Spill token dashboard helper exited with a non-zero status."
    cat "$HELPER_LOG_FILE"
    exit 1
fi
PID=""

if ! grep -q "SPILL_TOKEN_DASHBOARD_SMOKE_READY" "$HELPER_LOG_FILE"; then
    echo "FAIL: Spill token dashboard helper did not report smoke readiness."
    cat "$HELPER_LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_TOKEN_DASHBOARD_SMOKE_EXIT" "$HELPER_LOG_FILE"; then
    echo "FAIL: Spill token dashboard helper did not report smoke shutdown."
    cat "$HELPER_LOG_FILE"
    exit 1
fi

echo "OK: Spill runtime smoke test passed."
