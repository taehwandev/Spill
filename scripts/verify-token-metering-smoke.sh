#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXEC="$ROOT_DIR/.build/Spill.app/Contents/MacOS/Spill"
LOG_FILE="${TMPDIR:-/tmp}/spill-token-metering-smoke.log"
EVENTS_FILE="$(mktemp "${TMPDIR:-/tmp}/spill-token-metering-events.XXXXXX")"
INBOX_FILE="$(mktemp "${TMPDIR:-/tmp}/spill-token-metering-inbox.XXXXXX")"
PORT="${SPILL_TOKEN_METERING_SMOKE_PORT:-48732}"
PID=""

cleanup() {
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        wait "$PID" 2>/dev/null || true
    fi

    rm -f "$EVENTS_FILE" "$INBOX_FILE"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/build-app.sh"

rm -f "$LOG_FILE"

SPILL_SMOKE_TEST=1 \
SPILL_SMOKE_TEST_EXIT_AFTER=6.0 \
SPILL_TOKEN_USAGE_BRIDGE_PORT="$PORT" \
SPILL_TOKEN_USAGE_EVENTS_FILE="$EVENTS_FILE" \
SPILL_TOKEN_USAGE_INBOX_FILE="$INBOX_FILE" \
"$APP_EXEC" >"$LOG_FILE" 2>&1 &
PID="$!"

deadline=$((SECONDS + 8))
until curl -fsS "http://127.0.0.1:$PORT/v1/usage/health" >/dev/null 2>&1; do
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "FAIL: Spill exited before token bridge became healthy."
        cat "$LOG_FILE"
        exit 1
    fi

    if (( SECONDS >= deadline )); then
        echo "FAIL: Spill token bridge smoke test timed out waiting for health."
        cat "$LOG_FILE"
        exit 1
    fi

    sleep 0.2
done

SPILL_TOKEN_METERING_SMOKE_PORT="$PORT" node --input-type=module <<'NODE'
const port = process.env.SPILL_TOKEN_METERING_SMOKE_PORT;
const baseURL = `http://127.0.0.1:${port}`;
const timestamp = new Date().toISOString();
const compactTimestamp = timestamp.replace(/[-:.]/g, "").replace("Z", "");
const spanID = `span_smoke_${compactTimestamp}`;
const event = {
  schema_version: 1,
  device_id: "device_local",
  project_id: "project_global",
  artifact_id: "artifact_smoke",
  run_id: `run_smoke_${compactTimestamp}`,
  span_id: spanID,
  ai_tool: "codex",
  task_type: "debugging",
  stage: "verify",
  model: "spill-smoke-test",
  input_tokens: 32,
  output_tokens: 16,
  total_tokens: 48,
  token_breakdown: {
    system: 4,
    user: 4,
    history: 4,
    repo_context: 8,
    tool_output: 12,
    generated_output: 16,
    unknown: 0,
  },
  latency_ms: 1,
  created_at: timestamp,
  sync_mode: "local_only",
};

async function readEvents() {
  const response = await fetch(`${baseURL}/v1/usage/events`);
  if (!response.ok) {
    throw new Error(`GET events failed with ${response.status}`);
  }

  const envelope = await response.json();
  return Array.isArray(envelope.events) ? envelope.events : [];
}

const beforeEvents = await readEvents();
if (beforeEvents.length !== 0) {
  throw new Error(`smoke events file should start empty, found ${beforeEvents.length}`);
}

const postResponse = await fetch(`${baseURL}/v1/usage/events`, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
  },
  body: JSON.stringify(event),
});
if (postResponse.status !== 201) {
  throw new Error(`POST event failed with ${postResponse.status}`);
}

const afterEvents = await readEvents();
if (afterEvents.length !== 1) {
  throw new Error(`expected one stored event, found ${afterEvents.length}`);
}

const storedEvent = afterEvents[0];
if (storedEvent.span_id !== spanID) {
  throw new Error(`stored span id mismatch: ${storedEvent.span_id}`);
}
if (storedEvent.total_tokens !== 48 || storedEvent.input_tokens !== 32 || storedEvent.output_tokens !== 16) {
  throw new Error("stored token counts do not match smoke event");
}
if (storedEvent.token_breakdown.generated_output !== 16 || storedEvent.token_breakdown.unknown !== 0) {
  throw new Error("stored token breakdown does not match smoke event");
}
if (storedEvent.sync_mode !== "local_only") {
  throw new Error(`stored sync mode mismatch: ${storedEvent.sync_mode}`);
}

console.log(`OK: token bridge accepted and returned smoke event ${spanID}.`);
NODE

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
    | SPILL_TOKEN_USAGE_INBOX_FILE="$INBOX_FILE" node "$ROOT_DIR/scripts/spill-token-usage-hook.mjs" --strict

HOOK_SPAN_ID="$HOOK_SPAN_ID" SPILL_TOKEN_METERING_SMOKE_PORT="$PORT" node --input-type=module <<'NODE'
const port = process.env.SPILL_TOKEN_METERING_SMOKE_PORT;
const spanID = process.env.HOOK_SPAN_ID;
const response = await fetch(`http://127.0.0.1:${port}/v1/usage/events`);
if (!response.ok) {
  throw new Error(`GET events after hook failed with ${response.status}`);
}

const envelope = await response.json();
const events = Array.isArray(envelope.events) ? envelope.events : [];
if (events.length !== 2) {
  throw new Error(`expected two stored events after hook, found ${events.length}`);
}

const hookEvent = events.find((event) => event.span_id === spanID);
if (!hookEvent) {
  throw new Error(`hook event ${spanID} was not stored`);
}
if (hookEvent.model !== "spill-hook-test" || hookEvent.total_tokens !== 15) {
  throw new Error("stored hook event does not match expected totals");
}
if (hookEvent.ai_tool !== "claude") {
  throw new Error(`stored hook event ai_tool mismatch: ${hookEvent.ai_tool}`);
}
if (hookEvent.token_breakdown.unknown !== 15 || hookEvent.sync_mode !== "local_only") {
  throw new Error("stored hook event does not preserve local-only unknown breakdown");
}

console.log(`OK: token usage hook accepted and returned smoke event ${spanID}.`);
NODE

if ! wait "$PID"; then
    echo "FAIL: Spill exited with a non-zero status during token bridge smoke."
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

echo "OK: Spill token metering smoke test passed."
