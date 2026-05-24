#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXEC="$ROOT_DIR/.build/Spill.app/Contents/MacOS/Spill"
LOG_FILE="${TMPDIR:-/tmp}/spill-sleep-guard-smoke.log"
PID=""
ASSERTIONS=""

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
SPILL_SMOKE_START_SLEEP_GUARD=1 \
SPILL_SMOKE_TEST_EXIT_AFTER=3.0 \
"$APP_EXEC" >"$LOG_FILE" 2>&1 &
PID="$!"

system_assertion_seen=0
display_assertion_seen=0
deadline=$((SECONDS + 10))

while kill -0 "$PID" 2>/dev/null; do
    ASSERTIONS="$(pmset -g assertions)"

    if grep -q "pid ${PID}(Spill):.*PreventUserIdleSystemSleep" <<<"$ASSERTIONS"; then
        system_assertion_seen=1
    fi

    if grep -q "pid ${PID}(Spill):.*PreventUserIdleDisplaySleep" <<<"$ASSERTIONS"; then
        display_assertion_seen=1
    fi

    if [[ "$system_assertion_seen" == "1" && "$display_assertion_seen" == "1" ]]; then
        break
    fi

    if (( SECONDS >= deadline )); then
        echo "FAIL: Spill Sleep Guard smoke test timed out."
        cat "$LOG_FILE"
        printf '%s\n' "$ASSERTIONS"
        exit 1
    fi

    sleep 0.2
done

if ! wait "$PID"; then
    echo "FAIL: Spill exited with a non-zero status during Sleep Guard smoke."
    cat "$LOG_FILE"
    exit 1
fi
PID=""

if ! grep -q "SPILL_SMOKE_READY" "$LOG_FILE"; then
    echo "FAIL: Spill did not report smoke readiness."
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_SLEEP_GUARD_SMOKE_STARTED keepDisplayAwake=true" "$LOG_FILE"; then
    echo "FAIL: Spill did not start Sleep Guard with display awake."
    cat "$LOG_FILE"
    exit 1
fi

if [[ "$system_assertion_seen" != "1" ]]; then
    echo "FAIL: Sleep Guard did not create PreventUserIdleSystemSleep."
    cat "$LOG_FILE"
    printf '%s\n' "$ASSERTIONS"
    exit 1
fi

if [[ "$display_assertion_seen" != "1" ]]; then
    echo "FAIL: Sleep Guard did not create PreventUserIdleDisplaySleep."
    cat "$LOG_FILE"
    printf '%s\n' "$ASSERTIONS"
    exit 1
fi

if ! grep -q "SPILL_SMOKE_EXIT" "$LOG_FILE"; then
    echo "FAIL: Spill did not report smoke shutdown."
    cat "$LOG_FILE"
    exit 1
fi

echo "OK: Spill Sleep Guard smoke test passed."
