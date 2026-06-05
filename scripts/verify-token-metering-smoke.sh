#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXEC="$ROOT_DIR/.build/Spill.app/Contents/MacOS/Spill"
LOG_FILE="${TMPDIR:-/tmp}/spill-token-metering-smoke.log"
EVENTS_FILE="$(mktemp "${TMPDIR:-/tmp}/spill-token-metering-events.XXXXXX")"
INBOX_DIR="$(mktemp -d "${TMPDIR:-/tmp}/spill-token-metering-inbox.XXXXXX")"
PID=""

cleanup() {
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        wait "$PID" 2>/dev/null || true
    fi

    rm -f "$EVENTS_FILE"
    rm -rf "$INBOX_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/build-app.sh"

rm -f "$LOG_FILE" "$EVENTS_FILE"

HOOK_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
HOOK_COMPACT_TIMESTAMP="${HOOK_TIMESTAMP//[-:.]/}"
HOOK_COMPACT_TIMESTAMP="${HOOK_COMPACT_TIMESTAMP/Z/}"
HOOK_SPAN_ID="span_hook_${HOOK_COMPACT_TIMESTAMP}"
HOOK_RUN_ID="run_hook_${HOOK_COMPACT_TIMESTAMP}"
HOOK_EVENT_JSON="$(
    HOOK_TIMESTAMP="$HOOK_TIMESTAMP" \
    HOOK_SPAN_ID="$HOOK_SPAN_ID" \
    HOOK_RUN_ID="$HOOK_RUN_ID" \
    node --input-type=module <<'NODE'
const event = {
  schema_version: 1,
  device_id: "device_local",
  project_id: "project_global",
  artifact_id: "artifact_hook",
  run_id: process.env.HOOK_RUN_ID,
  span_id: process.env.HOOK_SPAN_ID,
  ai_tool: "claude",
  task_type: "debugging",
  stage: "verify",
  model: "spill-hook-test",
  input_tokens: 9,
  output_tokens: 6,
  total_tokens: 15,
  token_breakdown: {
    system: 0,
    user: 0,
    history: 0,
    repo_context: 0,
    tool_output: 0,
    generated_output: 0,
    unknown: 15,
  },
  latency_ms: 1,
  created_at: process.env.HOOK_TIMESTAMP,
  sync_mode: "local_only",
};

process.stdout.write(JSON.stringify(event));
NODE
)"

printf '%s' "$HOOK_EVENT_JSON" \
    | SPILL_TOKEN_USAGE_INBOX_DIR="$INBOX_DIR" node "$ROOT_DIR/scripts/spill-token-usage-hook.mjs" --strict

HOOK_SPAN_ID="$HOOK_SPAN_ID" INBOX_DIR="$INBOX_DIR" node --input-type=module <<'NODE'
import { readdir } from 'node:fs/promises';

const files = await readdir(process.env.INBOX_DIR);
const jsonFiles = files.filter((file) => file.endsWith(".json"));
const tmpFiles = files.filter((file) => file.endsWith(".tmp"));

if (jsonFiles.length !== 1) {
  throw new Error(`expected one queued JSON event, found ${jsonFiles.length}`);
}
if (tmpFiles.length !== 0) {
  throw new Error(`expected no leftover tmp files, found ${tmpFiles.length}`);
}

console.log(`OK: token usage hook queued event ${process.env.HOOK_SPAN_ID}.`);
NODE

SPILL_SMOKE_TEST=1 \
SPILL_SMOKE_OPEN_PANEL=1 \
SPILL_SMOKE_TEST_EXIT_AFTER=1.2 \
SPILL_TOKEN_USAGE_EVENTS_FILE="$EVENTS_FILE" \
SPILL_TOKEN_USAGE_INBOX_DIR="$INBOX_DIR" \
SPILL_TOKEN_USAGE_BRIDGE_DISABLED=1 \
"$APP_EXEC" >"$LOG_FILE" 2>&1 &
PID="$!"

deadline=$((SECONDS + 8))
while kill -0 "$PID" 2>/dev/null; do
    if (( SECONDS >= deadline )); then
        echo "FAIL: Spill token metering queue smoke test timed out."
        cat "$LOG_FILE"
        exit 1
    fi

    sleep 0.2
done

if ! wait "$PID"; then
    echo "FAIL: Spill exited with a non-zero status during token metering queue smoke."
    cat "$LOG_FILE"
    exit 1
fi
PID=""

HOOK_SPAN_ID="$HOOK_SPAN_ID" EVENTS_FILE="$EVENTS_FILE" INBOX_DIR="$INBOX_DIR" node --input-type=module <<'NODE'
import { readFile, readdir } from 'node:fs/promises';

const events = JSON.parse(await readFile(process.env.EVENTS_FILE, "utf8"));
if (!Array.isArray(events) || events.length !== 1) {
  throw new Error(`expected one stored event, found ${Array.isArray(events) ? events.length : "non-array"}`);
}

const event = events[0];
if (event.span_id !== process.env.HOOK_SPAN_ID) {
  throw new Error(`stored span id mismatch: ${event.span_id}`);
}
if (event.ai_tool !== "claude" || event.model !== "spill-hook-test") {
  throw new Error("stored event identity does not match expected hook event");
}
if (event.total_tokens !== 15 || event.input_tokens !== 9 || event.output_tokens !== 6) {
  throw new Error("stored token counts do not match hook event");
}
if (event.token_breakdown.unknown !== 15 || event.sync_mode !== "local_only") {
  throw new Error("stored hook event does not preserve local-only unknown breakdown");
}

const remaining = (await readdir(process.env.INBOX_DIR)).filter((file) => file.endsWith(".json"));
if (remaining.length !== 0) {
  throw new Error(`expected queued event to be drained, found ${remaining.length} files`);
}

console.log(`OK: Spill imported queued token event ${process.env.HOOK_SPAN_ID}.`);
NODE

if ! grep -q "SPILL_SMOKE_READY" "$LOG_FILE"; then
    echo "FAIL: Spill did not report smoke readiness."
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_PANEL_SMOKE_VISIBLE" "$LOG_FILE"; then
    echo "FAIL: Spill did not open the panel for token metering smoke."
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q "SPILL_SMOKE_EXIT" "$LOG_FILE"; then
    echo "FAIL: Spill did not report smoke shutdown."
    cat "$LOG_FILE"
    exit 1
fi

echo "OK: Spill token metering queue smoke test passed."
