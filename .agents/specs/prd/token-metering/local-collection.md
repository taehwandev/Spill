# Local Token Collection PRD

## Document Contract

- Status: active
- Audience: product, privacy, engineering, QA, and support maintainers
- Purpose: define safe local token collection, setup, normalization, and accuracy
- Source of truth: this document owns token event collection and local metering guarantees
- Related: [Spill PRD index](../../prd.md), [Spill ARD](../../ard.md),
  [Token Metering Dashboard](dashboard.md), [Token History Import](history-import.md)

## Product Boundary

Local token metering works independently from login, cloud upload, telemetry,
and the web application. This document owns collection and event accuracy. It
does not own dashboard layout or Private Usage Upload behavior.

## Local Store And Privacy Requirements

- The native app reads safe token usage from an app-owned local store.
- Token metering works without login, cloud upload, telemetry, or a running web
  app.
- Local usage records may include only numeric counts, timestamps, model ids,
  opaque ids, latency, token detail categories, safe `ai_tool`, `task_type`, and
  `stage` labels.
- Local usage records must never include prompts, responses, commands, file
  paths, repo names, branch names, terminal output, logs, diffs, source content,
  environment values, secrets, or arbitrary content-like fields.
- Spill uses one app-owned local token event store for dashboard reads.
  Runtime-specific hooks, importers, or SDK adapters normalize into that store;
  the app should not present Codex, Claude Code, and Antigravity/AGY as three
  separate product databases.
- Primary settings and dashboard surfaces must not expose the internal token
  event queue filesystem path or a copy-path action. Receiver path diagnostics
  belong only in developer-facing diagnostics when explicitly needed.
- A self-test may create synthetic token-only data, but must be clearly labeled
  as diagnostics.

## Setup And Runtime Source Requirements

- Setup UI should offer basic exact-token installation before the optional
  workflow-aware setup path.
- Setup UI in Preferences and the local token dashboard should inspect the
  app-owned setup files and adapter configuration to label the direct action as
  `Install` when setup is absent and `Reinstall` or `Repair` when setup already
  exists. This check is setup state, not evidence that a real AI turn produced
  token usage.
- Setup UI should describe basic metering as exact totals without work-type or
  stage labels. It should describe workflow-aware setup as an optional copied
  instruction that is run from the workflow-owning directory, without scanning
  unrelated directories.
- After a basic-metering install or repair, setup status and copied instructions
  must tell users that an AI tool session already in progress needs a restart or
  a new session before it can load the updated connection files.
- Setup UI and the copied agent install prompt must explicitly explain that
  supported local JSONL, transcript, or metadata stores may be read locally only
  for exact token metadata, and that prompts, responses, commands, file paths,
  logs, diffs, source content, environment values, and secrets are not stored or
  uploaded.
- Token metering settings must offer an explicit local history import action
  for the supported runtimes installed on this Mac. The action is user-initiated,
  not automatic on install, not scoped to whichever agent is currently running,
  and separate from cloud or account sync. Detailed requirements live in the
  [Token History Import PRD](history-import.md).
- Token metering setup and documentation must describe the primary collection
  path, runtime diagnostics, and rationale for each first-class AI runtime:
  - Codex: use a local session importer that reads exact token-count records
    from supported Codex session data and writes safe normalized events. This
    avoids depending on a prompt instruction alone and keeps collection tied to
    exact runtime usage records.
  - Claude Code: use the Stop-hook transcript contract when available. The hook
    receives a safe pointer to the transcript, reads only exact numeric usage
    metadata and safe opaque runtime metadata, and writes safe normalized
    events. This is acceptable because Claude Code exposes a post-turn contract
    that can carry exact usage.
  - Antigravity/AGY: use the local active importer as the primary path. It reads
    only exact numeric usage fields and safe opaque metadata from AGY
    conversation metadata and writes safe normalized events. AGY runtime hooks
    must not be installed for Spill metering because they can be skipped, can
    run with empty stdin, or can run without exact token fields for real text
    turns, which makes them misleading setup evidence.
  - Direct OpenAI SDK work: optional adapter support is allowed only when the
    SDK caller exposes exact usage from the model response and can submit the
    same strict safe event schema. It is not part of the default local agent
    dashboard.
- Hook execution, hook configuration, permission prompts, label-context writes,
  unit tests, smoke tests, or mock payload injection must not be described as
  proof that real runtime usage was recorded. Real proof is a strict safe event
  in the local queue/store or a runtime-specific success diagnostic for exact
  usage.

## Raw Usage And Accounting Requirements

- First-class tool comparisons must use raw exact token usage on the same
  baseline across runtimes. Claude Code cache-read tokens are part of raw input
  usage and must be included with uncached input and cache-creation tokens so
  Claude totals can be compared with Codex totals, whose input counts already
  include cached reads. Cost estimates may apply cache pricing weights later,
  but the stored/default usage total is raw tokens.
- Local storage and encrypted Private Usage Upload aggregates should preserve
  uncached input, cache-creation input, cache-read input, unclassified input,
  and reasoning output buckets when runtimes expose them so dashboard or web
  pricing layers can apply provider/model-specific rates without changing the
  raw usage baseline.
- Agent-facing status reads are a secondary reporting surface, not a metering
  source. They must not create usage events, write labels, run hooks, infer
  counts, inspect private content, or be reported as proof that the current turn
  was recorded.
- When a user explicitly asks an agent for `spill`, Spill status, token usage
  status, or local usage status, installed agents should be able to read the
  same app-owned local store through a read-only helper and return a self-scoped
  aggregate summary. The installed prompt should include concrete commands for
  `--tool codex`, `--tool claude`, and `--tool antigravity`, not only a generic
  placeholder. The helper must expose event count, total tokens, average event
  size, peak event size, model/task/stage breakdowns, token detail categories,
  and recent activity in addition to input/output totals.

## Resource And Freshness Requirements

- Atomic inbox files and store-change notifications are the primary live
  freshness path. Spill imports completed inbox events immediately without
  waiting for a dashboard or menu-bar timer.
- Automatic dashboard and menu-bar collection requests are recovery fallbacks
  and run no more often than every 30 minutes. Independent periodic callers
  share one policy instead of creating competing short polling loops.
- Non-user periodic requests run active importers and passive limit capture no
  more often than every 20 minutes, preventing nearby dashboard and menu-bar
  requests from repeating the same filesystem work. Inbox draining remains
  unthrottled.
- App launch, panel or dashboard open, explicit manual refresh, and Private
  Usage Upload freshness requests bypass the importer pacing floor. Lowering
  background work must not make a user action wait for the next fallback tick.

## Token Count Accuracy And Duplicate Prevention

- Token counts shown in the dashboard and sync must reflect exactly one event
  per AI turn. Runtime behavior that writes the same turn 2-3 times, such as
  Claude Code writing the same request ID with slightly different timestamps,
  must not produce multiple counted events.
- Dedup must not merge distinct turns. Two real turns that happen to share the
  same input and output token counts must each count as separate events. The
  dedup policy must use only safe, non-content signals such as timestamps, run
  IDs, and exact request IDs, and never inspect prompt or response content.
- Duplicate prevention uses a layered strategy whose specifics live in ARD and
  adapter docs. At the product level:
  - A runtime re-write of the same turn within a short window is counted once.
  - Exact-content duplicates with the same timestamp, tokens, tool, model, and
    workflow labels are collapsed in both the local store and sync.
  - Distinct turns from different tools or workflow stages are never merged,
    even when their token counts match.
- The local DB schema carries a monotonically increasing `user_version` to track
  which dedup migrations have run. One-time DB migrations apply dedup rules
  retroactively so historical over-counts can be corrected without requiring a
  full re-import.
- Private Usage Upload sync applies the same exact-content dedup policy before
  uploading aggregates. Sync must not apply a weaker or stricter policy than the
  local store or re-merge events that local dedup separated as distinct turns.
- Because local token metering has not shipped as a compatibility-boundary
  feature, existing experimental local usage rows, diagnostics, importer cursors,
  and adapter cache data do not require migration or backward compatibility.
  Development builds may reset or rebuild those local-only records when the
  schema or collection source changes, without loosening the privacy boundary.

## Acceptance

- Local token events appear without login when the local store receives a safe event.
- Safe event validation rejects content-like fields.
- Setup surfaces explain the Codex, Claude Code, Antigravity/AGY, and optional
  OpenAI SDK collection paths, including why AGY does not rely on hooks.
- Explicit agent-facing Spill status requests return self-scoped aggregates
  without exposing private content or acting as a metering source.
- Counts reflect exactly one event per real AI turn, duplicates are repaired,
  and distinct turns are preserved.
- Runtime mechanics remain in ARD and adapter documentation; this PRD owns the
  product accuracy and privacy guarantees.
- A continuously open dashboard or enabled menu-bar AI glance does not run
  automatic token collection more often than the 30-minute fallback policy,
  while newly queued events and explicit user refreshes still appear promptly.

## Verification

- Validate the strict safe event schema and rejection of extra content-like keys.
- Verify one real supported runtime turn produces one stored event.
- Verify duplicate rewrites collapse and distinct same-sized turns remain separate.
- Verify setup, diagnostics, and stats-helper execution are not treated as usage proof.
