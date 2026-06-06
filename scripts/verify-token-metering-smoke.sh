#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXEC="$ROOT_DIR/.build/Spill.app/Contents/MacOS/Spill"
LOG_FILE="${TMPDIR:-/tmp}/spill-token-metering-smoke.log"
EVENTS_FILE="$(mktemp "${TMPDIR:-/tmp}/spill-token-metering-events.XXXXXX.json")"
INBOX_DIR="$(mktemp -d "${TMPDIR:-/tmp}/spill-token-metering-inbox.XXXXXX")"
ADAPTER_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/spill-token-metering-adapters.XXXXXX")"
PID=""

cleanup() {
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        wait "$PID" 2>/dev/null || true
    fi

    rm -f "$EVENTS_FILE"
    rm -rf "$INBOX_DIR" "$ADAPTER_TMP_DIR"
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

printf '%s' '{"usage":{"input_tokens":11,"output_tokens":7},"model":"gemini-2.5-pro","session_id":"agySmokeRun01","task_type":"code_review","stage":"verify"}' \
    | SPILL_TOKEN_USAGE_INBOX_DIR="$INBOX_DIR" \
      python3 "$ROOT_DIR/Sources/Spill/Resources/adapters/antigravity/spill-hook.py"

AGY_DUP_INBOX="$ADAPTER_TMP_DIR/agy-duplicate-inbox"
mkdir -p "$AGY_DUP_INBOX"
for _ in 1 2; do
    printf '%s' '{"usage":{"input_tokens":11,"output_tokens":7},"model":"gemini-2.5-pro","session_id":"agySmokeRun01","task_type":"code_review","stage":"verify"}' \
        | SPILL_TOKEN_USAGE_INBOX_DIR="$AGY_DUP_INBOX" \
          python3 "$ROOT_DIR/Sources/Spill/Resources/adapters/antigravity/spill-hook.py"
done

AGY_DUP_INBOX="$AGY_DUP_INBOX" node --input-type=module <<'NODE'
import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';

const files = (await readdir(process.env.AGY_DUP_INBOX)).filter((file) => file.endsWith(".json"));
if (files.length !== 2) {
  throw new Error(`expected two AGY duplicate queue files, found ${files.length}`);
}
const spans = new Set(await Promise.all(files.map(async (file) => JSON.parse(await readFile(join(process.env.AGY_DUP_INBOX, file), "utf8")).span_id)));
if (spans.size !== 1) {
  throw new Error(`expected duplicate AGY payloads to share one stable span id, found ${spans.size}`);
}
NODE

CLAUDE_TRANSCRIPT="$ADAPTER_TMP_DIR/claude-transcript.jsonl"
CLAUDE_PAYLOAD="$ADAPTER_TMP_DIR/claude-payload.json"
CLAUDE_TRANSCRIPT="$CLAUDE_TRANSCRIPT" CLAUDE_PAYLOAD="$CLAUDE_PAYLOAD" node --input-type=module <<'NODE'
import { writeFile } from 'node:fs/promises';

const transcript = [
  { message: { role: "user" } },
  {
    message: {
      role: "assistant",
      model: "claude-sonnet-4",
      usage: {
        input_tokens: 13,
        cache_creation_input_tokens: 0,
        cache_read_input_tokens: 2,
        output_tokens: 5,
      },
      content: [{ type: "tool_use", name: "Read" }],
    },
  },
].map((line) => JSON.stringify(line)).join("\n");

await writeFile(process.env.CLAUDE_TRANSCRIPT, `${transcript}\n`);
await writeFile(process.env.CLAUDE_PAYLOAD, JSON.stringify({
  session_id: "claudeSmokeRun01",
  transcript_path: process.env.CLAUDE_TRANSCRIPT,
}));
NODE

SPILL_TOKEN_USAGE_SESSION_STATE_DIR="$ADAPTER_TMP_DIR/session-state-initial" \
SPILL_TOKEN_USAGE_INBOX_DIR="$INBOX_DIR" \
SPILL_TOKEN_USAGE_TASK_TYPE="git_commit" \
SPILL_TOKEN_USAGE_STAGE="summarize" \
python3 "$ROOT_DIR/Sources/Spill/Resources/adapters/claude-code/spill-hook.py" <"$CLAUDE_PAYLOAD"

CLAUDE_DUP_INBOX="$ADAPTER_TMP_DIR/claude-duplicate-inbox"
mkdir -p "$CLAUDE_DUP_INBOX"
for i in 1 2; do
    SPILL_TOKEN_USAGE_SESSION_STATE_DIR="$ADAPTER_TMP_DIR/session-state-dup-$i" \
    SPILL_TOKEN_USAGE_INBOX_DIR="$CLAUDE_DUP_INBOX" \
    SPILL_TOKEN_USAGE_TASK_TYPE="git_commit" \
    SPILL_TOKEN_USAGE_STAGE="summarize" \
    python3 "$ROOT_DIR/Sources/Spill/Resources/adapters/claude-code/spill-hook.py" <"$CLAUDE_PAYLOAD"
done

CLAUDE_DUP_INBOX="$CLAUDE_DUP_INBOX" node --input-type=module <<'NODE'
import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';

const files = (await readdir(process.env.CLAUDE_DUP_INBOX)).filter((file) => file.endsWith(".json"));
if (files.length !== 2) {
  throw new Error(`expected two Claude duplicate queue files, found ${files.length}`);
}
const spans = new Set(await Promise.all(files.map(async (file) => JSON.parse(await readFile(join(process.env.CLAUDE_DUP_INBOX, file), "utf8")).span_id)));
if (spans.size !== 1) {
  throw new Error(`expected duplicate Claude payloads to share one stable span id, found ${spans.size}`);
}
NODE

CODEX_HOME_DIR="$ADAPTER_TMP_DIR/codex-home"
CODEX_SESSION_DIR="$CODEX_HOME_DIR/sessions/2026/06/05"
mkdir -p "$CODEX_SESSION_DIR"
CODEX_SESSION="$CODEX_SESSION_DIR/rollout-spill-smoke.jsonl"
CODEX_SESSION="$CODEX_SESSION" node --input-type=module <<'NODE'
import { writeFile } from 'node:fs/promises';

const timestamp = new Date().toISOString();
const lines = [
  {
    timestamp,
    type: "session_meta",
    originator: "codex_cli_rs",
    session_id: "codexSmokeRun01",
    model: "gpt-5-codex",
  },
  {
    timestamp,
    type: "event_msg",
    payload: {
      type: "token_count",
      info: {
        model: "gpt-5-codex",
        last_token_usage: {
          input_tokens: 17,
          cached_input_tokens: 0,
          output_tokens: 6,
          reasoning_output_tokens: 4,
          total_tokens: 27,
        },
        total_token_usage: {
          input_tokens: 17,
          cached_input_tokens: 0,
          output_tokens: 6,
          reasoning_output_tokens: 4,
          total_tokens: 27,
        },
      },
    },
  },
].map((line) => JSON.stringify(line)).join("\n");

await writeFile(process.env.CODEX_SESSION, `${lines}\n`);
NODE

CODEX_LABEL_FILE="$ADAPTER_TMP_DIR/codex-label.json"
node "$ROOT_DIR/scripts/spill-token-metering-setup.mjs" \
    --label codex \
    --task-type review_response \
    --stage revise \
    --label-file "$CODEX_LABEL_FILE" \
    --ttl-minutes 5 \
    --json >/dev/null

NORMALIZED_LABEL_FILE="$ADAPTER_TMP_DIR/codex-normalized-label.json"
node "$ROOT_DIR/scripts/spill-token-metering-setup.mjs" \
    --label codex \
    --task-type code_generation \
    --stage verify \
    --label-file "$NORMALIZED_LABEL_FILE" \
    --ttl-minutes 5 \
    --json >/dev/null

NORMALIZED_LABEL_FILE="$NORMALIZED_LABEL_FILE" node --input-type=module <<'NODE'
import { readFile } from 'node:fs/promises';

const label = JSON.parse(await readFile(process.env.NORMALIZED_LABEL_FILE, "utf8"));
if (label.task_type !== "code_generation" || label.stage !== "implement") {
  throw new Error(`expected code_generation/implement label, found ${label.task_type}/${label.stage}`);
}
NODE

node "$ROOT_DIR/scripts/spill-codex-session-importer.mjs" \
    --codex-home "$CODEX_HOME_DIR" \
    --transport file \
    --inbox "$INBOX_DIR" \
    --events "$EVENTS_FILE" \
    --state "$ADAPTER_TMP_DIR/codex-state.json" \
    --label-file "$CODEX_LABEL_FILE" \
    --since-hours 1 \
    --json >/dev/null

if [[ -e "$CODEX_LABEL_FILE" ]]; then
    echo "FAIL: Codex label context should be consumed after a successful import."
    exit 1
fi

CODEX_REGRESSION_HOME="$ADAPTER_TMP_DIR/codex-regression-home"
CODEX_REGRESSION_INBOX="$ADAPTER_TMP_DIR/codex-regression-inbox"
CODEX_REGRESSION_EVENTS="$ADAPTER_TMP_DIR/codex-regression-events.json"
CODEX_REGRESSION_STATE="$ADAPTER_TMP_DIR/codex-regression-state.json"
CODEX_REGRESSION_SESSION_DIR="$CODEX_REGRESSION_HOME/sessions/2026/06/05"
mkdir -p "$CODEX_REGRESSION_SESSION_DIR" "$CODEX_REGRESSION_INBOX"
CODEX_REGRESSION_SESSION="$CODEX_REGRESSION_SESSION_DIR/rollout-spill-regression.jsonl"
CODEX_REGRESSION_SESSION="$CODEX_REGRESSION_SESSION" node --input-type=module <<'NODE'
import { writeFile } from 'node:fs/promises';

const base = Date.now() - 1000;
const records = [
  {
    input_tokens: 100,
    output_tokens: 10,
    reasoning_output_tokens: 0,
    total_tokens: 110,
    total: { input_tokens: 100, output_tokens: 10, reasoning_output_tokens: 0, total_tokens: 110 },
  },
  {
    input_tokens: 110,
    output_tokens: 15,
    reasoning_output_tokens: 0,
    total_tokens: 125,
    total: { input_tokens: 210, output_tokens: 25, reasoning_output_tokens: 0, total_tokens: 235 },
  },
  {
    input_tokens: 120,
    output_tokens: 20,
    reasoning_output_tokens: 5,
    total_tokens: 145,
    total: { input_tokens: 330, output_tokens: 45, reasoning_output_tokens: 5, total_tokens: 375 },
  },
];
const lines = [
  {
    timestamp: new Date(base).toISOString(),
    type: "session_meta",
    originator: "codex_cli_rs",
    session_id: "codexRegressionRun01",
    model: "gpt-5-codex",
  },
  ...records.map((record, index) => ({
    timestamp: new Date(base + index + 1).toISOString(),
    type: "event_msg",
    payload: {
      type: "token_count",
      info: {
        model: "gpt-5-codex",
        last_token_usage: {
          input_tokens: record.input_tokens,
          cached_input_tokens: 0,
          output_tokens: record.output_tokens,
          reasoning_output_tokens: record.reasoning_output_tokens,
          total_tokens: record.total_tokens,
        },
        total_token_usage: {
          cached_input_tokens: 0,
          ...record.total,
        },
      },
    },
  })),
].map((line) => JSON.stringify(line)).join("\n");

await writeFile(process.env.CODEX_REGRESSION_SESSION, `${lines}\n`);
NODE

node "$ROOT_DIR/scripts/spill-codex-session-importer.mjs" \
    --codex-home "$CODEX_REGRESSION_HOME" \
    --transport file \
    --inbox "$CODEX_REGRESSION_INBOX" \
    --events "$CODEX_REGRESSION_EVENTS" \
    --state "$CODEX_REGRESSION_STATE" \
    --task-type code_generation \
    --stage implement \
    --since-hours 1 \
    --json >/dev/null

node "$ROOT_DIR/scripts/spill-codex-session-importer.mjs" \
    --codex-home "$CODEX_REGRESSION_HOME" \
    --transport file \
    --inbox "$CODEX_REGRESSION_INBOX" \
    --events "$CODEX_REGRESSION_EVENTS" \
    --state "$CODEX_REGRESSION_STATE" \
    --task-type code_generation \
    --stage implement \
    --since-hours 1 \
    --json >/dev/null

CODEX_REGRESSION_INBOX="$CODEX_REGRESSION_INBOX" node --input-type=module <<'NODE'
import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';

const files = (await readdir(process.env.CODEX_REGRESSION_INBOX)).filter((file) => file.endsWith(".json"));
if (files.length !== 1) {
  throw new Error(`expected one latest Codex usage event after two importer runs, found ${files.length}`);
}
const event = JSON.parse(await readFile(join(process.env.CODEX_REGRESSION_INBOX, files[0]), "utf8"));
if (event.total_tokens !== 145 || event.input_tokens !== 120 || event.output_tokens !== 25) {
  throw new Error(`expected latest Codex last usage 120/25/145, found ${event.input_tokens}/${event.output_tokens}/${event.total_tokens}`);
}
if (event.task_type !== "code_generation" || event.stage !== "implement") {
  throw new Error(`expected code_generation/implement, found ${event.task_type}/${event.stage}`);
}
NODE

INBOX_DIR="$INBOX_DIR" node --input-type=module <<'NODE'
import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';

const files = (await readdir(process.env.INBOX_DIR)).filter((file) => file.endsWith(".json"));
if (files.length !== 4) {
  throw new Error(`expected four queued JSON events after adapter checks, found ${files.length}`);
}

const events = await Promise.all(files.map(async (file) => JSON.parse(await readFile(join(process.env.INBOX_DIR, file), "utf8"))));
const keys = new Set(events.map((event) => `${event.ai_tool}:${event.task_type}:${event.stage}`));
for (const expected of [
  "claude:debugging:verify",
  "antigravity:code_review:verify",
  "claude:git_commit:summarize",
  "codex:review_response:revise",
]) {
  if (!keys.has(expected)) {
    throw new Error(`missing adapter label event ${expected}`);
  }
}

console.log("OK: AGY, Claude, and Codex adapters queued detailed task labels.");
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

EVENTS_JSON_DATA=$(sqlite3 "${EVENTS_FILE%.json}.sqlite3" "SELECT json_group_array(json(payload_json)) FROM token_usage_events")

HOOK_SPAN_ID="$HOOK_SPAN_ID" EVENTS_JSON_DATA="$EVENTS_JSON_DATA" INBOX_DIR="$INBOX_DIR" node --input-type=module <<'NODE'
import { readdir } from 'node:fs/promises';

const events = JSON.parse(process.env.EVENTS_JSON_DATA);
if (!Array.isArray(events) || events.length !== 4) {
  throw new Error(`expected four stored events, found ${Array.isArray(events) ? events.length : "non-array"}`);
}

const event = events.find((candidate) => candidate.span_id === process.env.HOOK_SPAN_ID);
if (!event) {
  throw new Error("stored synthetic hook event missing");
}
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

const keys = new Set(events.map((candidate) => `${candidate.ai_tool}:${candidate.task_type}:${candidate.stage}`));
for (const expected of [
  "antigravity:code_review:verify",
  "claude:git_commit:summarize",
  "codex:review_response:revise",
]) {
  if (!keys.has(expected)) {
    throw new Error(`stored events missing adapter label ${expected}`);
  }
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
