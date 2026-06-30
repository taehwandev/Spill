---
title: Claude Code Native Active Importer
audience: Codex, Claude Code, Antigravity/AGY
purpose: Architecture rules and invariants for TokenUsageClaudeCodeImporter
status: stable
source_of_truth: Sources/Spill/TokenMetering/Importers/ClaudeCode/
last_verified: 2026-06-26
related: .agents/build-and-run.md, AGENTS.md
---

# Claude Code Native Active Importer

This doc is the authoritative design reference for `TokenUsageClaudeCodeImporter`.
Read it before touching any file under `Sources/Spill/TokenMetering/Importers/ClaudeCode/`.

## Why this exists

The Claude Code Stop hook fires only at process exit. Long sessions lose all
intermediate turns if the process does not exit cleanly. This native Swift
importer reads Claude Code's own JSONL transcript files directly (same pattern
as the AGY importer reading SQLite, and Codex reading session files).

## Source data

Claude Code writes per-session transcripts to:

```
~/.claude/projects/{project-hash}/{session-uuid}.jsonl
```

Each `type: assistant` line has `message.usage.{input_tokens,
cache_creation_input_tokens, cache_read_input_tokens, output_tokens}` and a
top-level `requestId` (e.g. `req_011Cbjmdtxv8Zv1jDj8kuQAq`).

Claude Code deletes old session files. Do not assume files persist indefinitely.

## span_id — must match Python Stop hook exactly

The Python Stop hook (`adapters/claude-code/spill-hook.py`) generates span_ids
via `_stable_span_id`. The Swift importer must produce identical values so
`appendEventsWithoutLoading` can deduplicate across both sources.

```
span_id = "span-" + sha256(":".join([
    session_id,           # run_id — session UUID directly, no hashing
    model,                # raw model string from message.model
    request_id,           # from JSONL top-level requestId field
    str(turn_index),      # see turn_index rules below
    timestamp,            # raw ISO8601 string from JSONL timestamp field
    str(span_input),      # input_tokens + cache_creation_input_tokens
    str(output_tokens),   # output_tokens
]))[:12]
```

### run_id

Use the session UUID string directly. Python's `_opaque()` passes it through
unchanged since UUID format matches `[A-Za-z0-9_-]{6,128}`.

Do NOT hash the session ID for run_id.

### cache token rules

- Store `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`
  as the event `input_tokens`. This matches the Codex measurement baseline
  because Codex `input_tokens` already includes cached input reads.
- Preserve `input_tokens`, `cache_creation_input_tokens`, and
  `cache_read_input_tokens` as local-only token accounting buckets when writing
  to the app-owned store or inbox sidecar. These buckets are not allowed in the
  strict usage event JSON, but they are required for model-specific cost
  estimates and encrypted aggregate sync.
- Keep `cache_read_input_tokens` out of the `span_id` input component. The
  identity component is `span_input = input_tokens +
  cache_creation_input_tokens`. This preserves stable event identity when
  repairing older Claude rows that undercounted raw input by omitting
  cache-read tokens. Both Python Stop hook and Swift importer must use this
  same identity formula. This applies to every Python emission path, including
  live Stop-hook events and `--scan-dir` history imports.

### turn_index

`turn_index` is a 0-based sequential counter of valid assistant turns per
session file. "Valid" means non-zero `input + output` after cache rules.

**Critical**: `turn_index` is persistent across collection cycles. It is stored
in `ImportState.nextTurnIndexBySource` alongside the byte offset.

- When a session is read for the first time: `startingTurnIndex = 0`.
- After reading N new turns: save `nextTurnIndexBySource[key] = prior + N`.
- On the next collection cycle: resume from the saved index.

This matches Python's behavior: Python reads from `byte_offset` and assigns
sequential indices starting from 0 for that batch. If both Python and Swift
start from the same `byte_offset` (both at 0 for first read), their indices
match. Persistent `nextTurnIndexBySource` keeps subsequent reads in sync.

**Never** reset `turn_index` to 0 per collection cycle. Doing so produces
different `turn_index` values for the same turns, breaking span_id dedup.

## State file

Path: `~/Library/Application Support/Spill/token-metering/session-state/claude-active-importer-state.json`

```json
{
  "schema_version": 1,
  "ai_tool": "claude",
  "byte_offset_by_source": { "<24-char-hex>": 12345 },
  "next_turn_index_by_source": { "<24-char-hex>": 42 }
}
```

State keys are `sha256(sessionID)[:24]` — opaque hashes of the session UUID.
Do NOT use file paths or relative paths as state keys.

### Legacy state migration

If a state file exists but has no `next_turn_index_by_source` key, it was
written by a pre-index version of the importer. Return a completely fresh
`ImportState` (empty offsets AND empty indices). This forces a full re-scan
from `byte_offset = 0` so `turn_index` starts correctly from 0 for all
sessions.

Do NOT try to infer `turn_index` from existing `byte_offset` values.

## Discovery

Session files are discovered by enumerating `~/.claude/projects/` recursively.

Session ID validation regex: `^[0-9a-f-]{32,}$`

Claude session IDs are UUID v4 format (lowercase hex + hyphens, 36 chars).
Do NOT use a looser regex like `^[A-Za-z0-9_-]{6,64}$` — it admits non-session
files.

## Date filter / lookback window

The importer has no lookback window. `discoverSessionFiles` scans all JSONL
files. Byte-offset cursors handle efficiency: files with no new bytes are
skipped in O(1). A date filter would miss history after state reset or on first
install.

The coordinator's default runner must call `importRecentSessions` WITHOUT a
time-restricted `since:` argument — use the `.distantPast` default.

Do NOT pass `since: Date().addingTimeInterval(-24 * 60 * 60)` or any short
lookback. This breaks the full-history scan after state reset.

## Collection trigger

`TokenUsageCollectorCoordinator.runClaudeCodeActiveImporter()` triggers the
importer as part of the standard collection cycle (same cycle as AGY). The
coordinator calls `requestCollection(reason:)` on app events such as token
dashboard open and periodic background ticks.

## Dedup

`store.appendEventsWithoutLoading(events)` deduplicates by `span_id`. Events
already in the store are skipped. This means:

- Python Stop hook events and Swift importer events for the same turn produce
  the same `span_id` → only one is stored.
- Legacy events written with the old `span_` prefix (sha256 of sessionID +
  messageUUID) are NOT deduplicated against new `span-` events and represent
  duplicate data. Clean them up with:
  ```sql
  DELETE FROM token_usage_events
  WHERE ai_tool='claude' AND substr(span_id,1,5)='span_';
  ```

## Files and responsibilities

| File | Responsibility |
|------|---------------|
| `TokenUsageClaudeCodeImporter.swift` | Class definition, init |
| `TokenUsageClaudeCodeImporter+Defaults.swift` | Default paths, `opaqueHash`, `safeModel`, `safeAdd`, `sourceStateKey(for:String)` |
| `TokenUsageClaudeCodeImporter+Discovery.swift` | Enumerate `~/.claude/projects/` JSONL files |
| `TokenUsageClaudeCodeImporter+Parsing.swift` | Read new bytes, parse turns, assign turn_index |
| `TokenUsageClaudeCodeImporter+State.swift` | Load/save `ImportState`, legacy migration guard |
| `TokenUsageClaudeCodeImporter+LabelTimeline.swift` | Read `claude-timeline.jsonl`, match labels by timestamp |
| `TokenUsageClaudeCodeImporter+EventFactory.swift` | Build `TokenUsageEvent` with Python-matching span_id |
| `TokenUsageClaudeCodeImporter+ImportRecentSessions.swift` | Main loop: discover → parse → events → store → save state |
| `TokenUsageClaudeCodeImportSummary.swift` | Result struct |
