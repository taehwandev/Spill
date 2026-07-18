# Token History Import PRD

## Document Contract

- Status: active
- Audience: product, privacy, engineering, QA, and support maintainers
- Purpose: define explicit local history reconciliation for supported AI runtimes
- Source of truth: this document owns token history import product requirements
- Related: [Spill PRD index](../../prd.md), [Spill ARD](../../ard.md),
  [Local Token Collection](local-collection.md)

## Purpose

Token Metering settings must provide an explicit local history import action for
first-class local AI runtimes installed on this Mac:

- Codex
- Claude Code
- Antigravity/AGY

This action is a user-initiated local backfill and reconciliation job. It is not
automatic install behavior, not account sync, and not cloud sync.

## Product Requirements

- The settings UI provides one full sync action for the currently installed
  supported runtimes and one per-tool sync action for each installed runtime.
  Absent runtimes do not appear as rows and are not attempted by the normal All
  action.
- Runtime eligibility uses the same safe executable or app-bundle installation
  detection as the token dashboard and AI Visible controls. A running process
  is not required, and an empty or incomplete refresh must not fall back to all
  three tools.
- A per-tool sync reconciles only that tool's app-owned usage rows and that
  tool's history import cursor state. It must not clear, rescan, or mutate the
  other supported tools.
- The import is not scoped to whichever agent is currently running.
- A runtime that is installed but has missing local sources or no exact usage
  reports that as a per-tool result and does not block the other selected tools.
- Every explicit import scans supported local history for its selected scope
  from the local runtime sources and reconciles it into the app-owned store.
  Spill resets only the matching tool-specific history import cursors before
  scanning so the source is read from the beginning, but it must not delete
  existing usage rows as part of ordinary sync.
- Same-day history must not be skipped only because an import already ran that
  day. Manual refresh is a fresh reconciliation, not an incremental shortcut.
- Preferences may start, cancel, retry, and observe the job, but closing
  Preferences or switching settings sections must not cancel or reset it.
- App launch, panel refresh, dashboard refresh, menu bar status refresh, and
  general collection requests may drain already queued event files, but they
  must not start Codex, Claude Code, or Antigravity/AGY history importers.
- The UI reports per-tool progress, imported events, skipped duplicates,
  unsupported/no-exact-usage records, failures, cancellation, interruption, and
  last sync result. Last sync result must persist outside Preferences view
  lifetime so closing/reopening Preferences or switching settings sections does
  not erase the last visible per-tool result.
- Manual settings refresh should be presented as a full local reconciliation
  for the selected supported tools, not as a destructive rebuild.
- Destructive local token-store clearing is not part of history import. It must
  stay behind developer/debug-only surfaces and must not be exposed as a normal
  user repair or sync action.
- MVP first import uses progress and cancellation instead of a date-range
  picker. Later 7-day, 30-day, all-time, or custom-range controls may be added
  only if they preserve the same idempotent import contract.

## Supported Sources

Importers may read only known local runtime usage stores:

| Tool | Source |
| --- | --- |
| Codex | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` |
| Claude Code | `~/.claude/projects/**/*.jsonl`, including `subagents/*.jsonl` |
| Antigravity/AGY | Known local conversation metadata sources handled by the active importer |

Codex may use broader `~/.codex/sessions/**/rollout-*.jsonl` discovery only as
a compatibility fallback when the importer explicitly supports that shape.

## Privacy Boundary

Importers may parse only exact numeric usage records and safe opaque runtime
metadata. They must not store prompts, responses, commands, file paths,
repository names, branches, transcript content, logs, diffs, source content,
environment values, secrets, conversation titles, work item titles, or local
aliases.

Setup and history-import UI must disclose that Codex/Claude JSONL or transcript
stores and AGY metadata stores may be read locally for exact token metadata, and
must state that content-like fields are not stored or uploaded.

The normalized local source path may be used only in memory while deriving a
cursor key. It must not be written to cursor state, event payloads,
diagnostics, or cloud-synced data.

## Import Mode

Settings-triggered import is a full local reconciliation for the selected
scope. The All action scans local history for the current installed supported
tool set and resets only those tools' history-import cursor state so their
sources are reread. A per-tool action does the same only for that selected
installed tool.

The intended user flow is:

1. Install or refresh the local metering setup so future runtime events can get
   exact usage and trusted workflow labels.
2. If the user wants older local history from this Mac, run the local history
   import once after setup. Later repairs should prefer per-tool import unless
   the user intentionally wants every supported source checked again.

Cursor existence alone must never cause a manual settings refresh to skip old
local history. Cursors are optimization checkpoints for non-destructive
background collection paths only; the settings action must reread the selected
local sources and merge the result by stable event identity.

Importer-side duplicate filters must not block this settings reconciliation
from reaching the app store. Manual Codex history sync re-emits previously seen
stable span ids for the selected local sources, and the app store resolves them
by stable identity. Normal live or incremental collection paths may still use
adapter-side duplicate filters to avoid noisy queue growth.

Existing rows with the same stable event identity are preserved as the
authority for workflow labels, project ids, local display metadata, and other
user-visible grouping metadata. Reconciliation may repair exact numeric usage
fields for the same stable event identity when an importer bug or newer parser
produces a more accurate token count, but it must not overwrite the existing
row's grouping metadata. Newly discovered rows use trusted runtime/workflow
label timelines for their source event timestamp; if no trusted label covers
that timestamp, they use the safe fallback `uncategorized/summarize`.

Label restoration is evidence-bound:

- If an existing app-owned row with the same `ai_tool` and `span_id` already
  exists, that row's existing label and grouping metadata remain authoritative.
- If the row is new and the source event timestamp falls inside a trusted
  per-tool timeline entry, the importer applies that timeline label.
- If neither condition is true, the importer must not infer a label from tool
  names, commands, transcripts, prompts, paths, or content. It must use
  `uncategorized/summarize`.

Day boundaries use the user's current local calendar and timezone for reporting
and dashboard filtering. The import itself is source-wide and preserves each
event's source timestamp.

## Timestamp Fidelity

History import must preserve the source event timestamp exposed by each local
runtime. Import start time, sync completion time, database file modification
time, and scanner execution time must not be used as `created_at` for
historical usage rows when the source event timestamp is missing.

Tool-specific timestamp rules:

- Codex history uses each `token_count` record timestamp.
- Claude Code history uses the final assistant usage record timestamp for each
  stable request/message id. Claude transcript files may contain repeated
  assistant usage snapshots for the same runtime request; history scans must
  deduplicate those snapshots and keep the final usage record instead of
  summing every repeated snapshot. Live Stop-hook fallback may use current time
  only for a just-finished runtime event; history scans must count
  timestamp-less usage records as unsupported.
- Antigravity/AGY uses the numeric generation timestamp exposed inside the
  local conversation metadata blob. The AGY active importer must not use
  conversation database mtime as event time. Rows with exact usage but no
  trusted numeric generation timestamp are unsupported instead of being assigned
  to the sync day.

## Cursor And Checkpoint Rules

The history import job is owned by an app-wide coordinator. The caller passes
the installed selected tool scope, and the coordinator starts one per-tool task
for that scope on every explicit run.

Source cursors are local-only support state. They may contain:

- tool id
- opaque source id
- timestamps
- file size
- byte offset
- cumulative usage counters
- importer version

They must not contain raw source paths or content-like values.

Opaque source ids are derived from stable local source identity without storing
the source path. The intended form is:

```text
sha256(ai_tool + ":" + importer_source_version + ":" + normalized_relative_source_path)
```

Checkpoints are saved after each successfully processed source or small batch,
before the next source starts. A crash or cancellation may cause the current
source to be reread, but stable event identity and store-level duplicate checks
must make that safe.

## Duplicate And Event Identity Rules

Event identity must be stable across reruns. The store should enforce duplicate
resistance by `ai_tool` plus `span_id`.

Import summaries must report skipped duplicates separately from unsupported
records.

Codex import summaries must include content-free diagnostic counts for the
delta source used by imported records, including `last_token_usage` and
trusted-cursor `total_token_usage` deltas, plus a count of cumulative-only
records rejected because no trusted prior cumulative cursor existed. These
diagnostics may contain only counts and fixed field names, never source paths,
session ids, prompts, responses, commands, logs, diffs, source text, or
environment values.

History importers should enqueue large backfills as batch JSONL inbox files
rather than one JSON file per event. The app store must import both legacy
single-event `.json` files and batch `.jsonl` files from the inbox. This keeps a
full Codex, Claude Code, or AGY reconciliation from creating tens of thousands
of filesystem entries and freezing the app.

Tool-specific partitioning:

- Codex history is discovered by local session date directories and reconciled
  by session cursor deltas. When a Codex `token_count` record contains both
  `last_token_usage` and `total_token_usage`, the emitted Spill event must use
  `last_token_usage` as the per-call token amount. `total_token_usage` is
  cumulative session support data and may be used for cursors or as a fallback
  only when no `last_token_usage` is present and the importer already has a
  positive prior cumulative cursor for that same source. A current-window
  cumulative-only record without a trusted prior cursor is unsupported, not a
  new event. Codex cached-input policy is a separate measurement decision and
  must not be changed by history import.
- Claude history is partitioned by transcript source, including subagent
  sources, with per-source byte offsets and aggregate counters. Claude raw
  input usage must include `input_tokens`, `cache_creation_input_tokens`, and
  `cache_read_input_tokens`; omitting cache-read tokens makes Claude
  incomparable with Codex, whose `input_tokens` already include cached reads.
  Claude event identity must remain stable across this measurement repair by
  using the cache-read-excluding identity input in `span_id`; repeated imports
  should update numeric token fields for the same row rather than create a
  duplicate historical event.
- Codex, Claude, and AGY importers must preserve exact pricing-relevant bucket
  splits when the runtime exposes them. Raw event `input_tokens` remains the
  comparable total. Separate local-only accounting records carry uncached input,
  cache-creation input, cache-read input, and reasoning output. File-based
  adapters may write these numbers in a same-basename `.accounting` sidecar
  beside the strict `.json`/`.jsonl` inbox event file; the sidecar is not part
  of the strict usage event schema and must never contain prompts, responses,
  paths, logs, source, commands, or other content-like data.
- AGY history is partitioned by opaque conversation or generation identifiers
  exposed by the active importer. Records without exact token fields are
  skipped and counted as unsupported; they must not be estimated.

## Sync Boundary

Local history import only writes the app-owned local usage store and local
cursor/diagnostic state. Any future cloud usage sync is a separate app policy
applied after local import and must remain opt-in.
