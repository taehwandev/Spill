# Private Usage Upload PRD

## Document Contract

- Status: active
- Audience: product, privacy, security, engineering, QA, and release maintainers
- Purpose: define native encrypted aggregate upload behavior
- Source of truth: this document owns the macOS Private Usage Upload contract
- Related: [Spill PRD index](../../prd.md), [Spill ARD](../../ard.md),
  [Local Token Collection](local-collection.md), [Web Companion Contract](web-companion-contract.md)

## Product Boundary

Private Usage Upload is an optional app policy applied after local collection.
The native app uploads encrypted aggregates and never uploads raw token events or
downloads cloud usage data.

## Requirements

- The native app should avoid repeated macOS Keychain prompts during connection,
  app restart, Preferences open, and manual sync. A connected device stores its
  upload credential, browser key-wrapping secret, and local sealing-key ring as
  one environment-scoped Keychain bundle item instead of separate items.
- Private Usage Upload is opt-in.
- The app uploads only end-to-end encrypted, pre-aggregated usage buckets
  through a Spill relay API.
- The app never writes directly to the database, object storage, or vendor SDK.
- The native app never downloads cloud usage data.
- MVP upload cadence is daily and opportunistic: previous-day sealed buckets
  upload the next time the user is active and network is available.
- Before automatic upload or Manual Sync Now builds encrypted daily buckets, the
  app runs the lightweight local collection and inbox-drain path once so queued
  exact-usage events are included before sync.
- After initial connection and backfill, preparation is incremental. The app
  persists a local event-change cursor plus affected local day ids, reads only
  those ranges, and rebuilds only their encrypted bucket and shared summary.
- Local day ids use Gregorian `yyyy-MM-dd` regardless of the user's preferred
  system calendar. Parsing uses the same Gregorian calendar and bucket timezone.
- Aggregate generation is content-stable. An unchanged local day keeps the same
  canonical payload and hashes across later sync times, so it is acknowledged
  without another upload.
- Interrupted or failed batches retain affected day ids for retry. The cursor
  advances only after relay acknowledgement or a verified no-op day.
- If deletion or reconciliation leaves a dirty day with no remaining events, the
  app uploads a deterministic zero aggregate for the same bucket key instead of
  adding an incompatible delete or tombstone shape.
- Upload acknowledgements and change cursors bind to a local fingerprint of the
  relay device id and browser wrapping-key id. First connection, target change,
  or reconnect after explicit disconnect clears prior acknowledgements and
  seeds every existing local day for a bounded resync.
- Manual Sync Now performs one explicit upload attempt after the freshness pass
  and may include the current local day's partial daily bucket. Later syncs
  safely replace the same daily bucket.
- Encrypted daily buckets include token accounting totals used for local cost
  estimates, grouped by tool, model, task, stage, workflow coverage, and Work
  Item. Only aggregate counts and safe labels are uploaded.
- Plaintext shared summaries are a member-readable aggregate contract for
  dashboards that cannot decrypt sealed buckets. They preserve the same safe
  Work Item list: id, AI tool, task type, stage, model, totals, first event time,
  and last event time.
- Shared summaries must not include prompts, responses, commands, file paths,
  repo names, branch names, terminal output, logs, diffs, source content,
  environment values, secrets, raw event ids, `run_id`, or `span_id`.
- Multi-day backlogs remain queued locally and may upload later in one or more batches.
- Existing installations may enqueue one one-time historical change-journal
  backfill after upgrading. Later syncs are limited to inserted, effectively
  updated, or removed local event days.
- After the cursor and pending day ids are saved, consumed change-journal rows
  may be pruned through that cursor. Pruning never runs before retry state is
  persisted and preserves changes newer than the committed cursor.
- When development and production both retain connections, pruning stops at the
  minimum committed cursor across environments. A disconnected environment is
  excluded because reconnecting it seeds a full local resync checkpoint.

## Acceptance

- The native token monitoring UI can expose optional sign-in without implying
  login is required for local metering.
- Cloud upload can be disabled without affecting local metering.
- No raw events or content-like data are uploaded.
- Server-side plaintext token totals are not required for the web dashboard.
- Unchanged days do not upload again, failed days remain retryable, and deleted
  content produces a deterministic zero aggregate.
- Detailed relay, E2EE key custody, storage backend, and retry behavior remain
  aligned with the private Spill-web PRD and follow-on ARD.

## Verification

- Verify opt-in, disconnected, offline, retry, no-op, partial-day, and zero-day paths.
- Verify the strict aggregate allowlist and rejection of raw event identifiers.
- Verify cursor persistence precedes pruning and changed targets force bounded resync.
