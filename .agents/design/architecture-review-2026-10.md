# Spill Architecture Review — October 2026

## Scope and decision

Reviewed current native source, bundled adapters, canonical PRD/ARD, and synthetic
regression fixtures. No user transcripts, usage database, credentials, or private
web backend were inspected. This is a source-level assessment; it does not prove
that every live collection path or remote privacy policy behaves correctly.

Keep the existing local-first architecture. The main process owns collection and
network work; the dashboard helper reads local data and requests refreshes;
feature stores own UI state. SQLite is the event authority, while optional upload
produces encrypted aggregates. Atomic inbox writes, durable cursors, shared
settings notifications, and transactional dashboard queries support these
boundaries. A new framework or package split is not required to fix the findings.

The immediate direction is to make event identity, numeric-detail validity, and
presentation scope explicit at their existing owners. Follow-on concurrency and
runtime identity work needs its own design and deterministic tests.

## Bounded corrections

| Finding | Correction and verification |
| --- | --- |
| Old-schema cleanup can delete legitimate spans with equal usage, even across tools or stages. | Retire count/time similarity deletion while preserving schema advancement. Synthetic v2/v9 upgrades must retain every distinct span. Exact primary-key dedup remains. |
| A same-span total update can retain incompatible accounting. Event decoding drops the row while SQL/stat views interpret it differently. | Replace accounting atomically. Preserve prior detail only with unchanged input and output; otherwise missing incoming detail becomes unknown. Verify decrease, increase, output change, unchanged totals, and exact replacement. |
| Private daily aggregation merges distinct spans with identical safe fields. | Include trusted span identity in local duplicate checks. Verify both encrypted buckets and plaintext shared summaries retain two identical-looking distinct events; repeated identical span still counts once. Wire schema remains unchanged. |
| Fresh-only KPI comparison subtracts a projected previous total from a raw current total. | Use the applied snapshot scope for the current total; the previous total is already projected. Verify 0%, increase, decrease, absent/zero previous usage, and pending-to-applied scope transition. |
| Public installer copies lag the source/bundled stats helper and omit its two sibling modules. | Synchronize canonical helper/instruction copies, download both modules, and carry their static routes into the web mirror. Extend the isolated stats check to cover public copies and download paths. |
| Python Claude hook rereads and parses the whole label timeline for every emitted event. | Share one lazy, safe-label snapshot per invocation across main/history/subagent batches. Preserve interval/tie semantics and reload on the next invocation; no persistent cache, timer, or event fields. |
| Python transcript reading advances its cursor over an incomplete final JSON/UTF-8 record. | Retain the cursor before the incomplete tail and resume after append. Continue accepting complete JSON without a final newline and skipping malformed terminated rows; avoid opening unchanged transcripts. |
| A main no-delta result skips child discovery; only the legacy sibling child directory is searched. | Check session-stem and legacy subagent directories independently of the main outcome, without a date lookback. Keep existing opaque identity, cursors and strict event/accounting contracts. |

These corrections prevent future losses/inconsistency; they do not restore
previously deleted rows or rewrite existing runtime span identities. They add no
settings, polling loops, uploads, or new persistent event fields.

## Follow-on design, in priority order

| Priority | Evidence and failure scenario | Direction and nearest check |
| --- | --- | --- |
| P1 | [Upload acknowledgement](../../Sources/Spill/TokenMetering/PrivateUsage/Upload/PrivateUsageUploadCoordinator+State.swift) reloads current state after awaiting a response for an older connection. An old success or revoked response can alter a replacement connection. Several coordinator instances share persistent state. | One shared per-environment state owner plus persisted connection generation. Compare generation before every acknowledgement, cursor/prune, failure, and revoke effect. Suspend connection A's relay response, connect B, then resume A; B's credentials and pending work must remain intact. An instance lock or actor alone does not protect across instances or an await. |
| P1 | [Claude parsing](../../Sources/Spill/TokenMetering/Importers/ClaudeCode/TokenUsageClaudeCodeImporter+Parsing.swift) intentionally keeps the first usage snapshot for a repeated request; emitted-request state rejects later updates. The history contract requires the final exact snapshot. | Design stable request identity and numeric replacement together for Swift and Python. Retain the mandatory [importer invariants](claude-code-importer.md) until an explicit replacement contract is reviewed. Test same-batch, split-batch, and native/hook parity. Do not merely change first to last with a mutable-count span hash. |
| P1 privacy risk | [AGY fallback reader](../../Sources/Spill/TokenMetering/Importers/Antigravity/Discovery/TokenUsageAntigravityImporter+DatabaseReader.swift) copies the complete source database and sidecars into a temporary directory. Normal cleanup exists, but a crash can leave copies. Presence of private content in a real database was not inspected. | Prefer a read-only numeric projection/snapshot; fail closed if a safe exact read is unavailable. Use a synthetic database with an unrelated private-content column to verify the fallback never persists it. |
| P2 | [Codex adapter](../../Sources/Spill/Resources/adapters/codex/spill-importer.mjs) includes the source path in span hashing even when an opaque runtime session ID exists. Moving or copying the same runtime records can produce new identities. | Separate local file cursors from usage identity. Test the same safe runtime records at two source locations; use exact runtime identity/cursors and a content-free opaque fallback. |
| P2 | The compact panel loads today's usage but [its label](../../Sources/Spill/Panel/SpillBarAITokenSummary.swift) follows the menu-bar Total/Cycle choice. Project-filtered dashboard comparison can omit the prior period or compare against all projects. | Make the panel period explicit. Load comparison data for the same period/tool/project/scope as the headline. Verify a two-project/two-day fixture and every menu-bar mode. |
| Hardening | Telemetry accepts arbitrary properties and crash reporting retains some tags. Inspected callers use safe fields; a current content leak was not demonstrated. | Typed product events/reasons and a final outbound tag allowlist, checked with synthetic content-like values. |

The private web service's authorization, decryption, retention, and deletion
behavior remains outside this repository's verified boundary. Review that owner
separately before making end-to-end privacy claims.

## Verification boundary

The parent owns integration and focused Swift regression execution; independent
workers own storage integrity, dashboard comparison, and aggregate preservation.
Architecture code gates and canonical documentation checks complement tests.
Observed focused verification: 288 Swift tests and 8 isolated stats tests passed
with zero failures. Fixtures reproduce the former migration, accounting, and
aggregate failures before the corrections. These tests do not exercise a live
runtime turn or a production web deployment.
Live history repair, backend deployment, runtime identity migration, and upload
connection-generation redesign are outside this bounded correction.

## Large-history calendar follow-up

The calendar complaint was reproduced on a synthetic 100,000-event SQLite store:
80,000 events on one local October day and 20,000 on one September day, evenly
split across Codex and Claude. Fixture creation is excluded. The same debug
Swift test awaits each actual asynchronous store action before reporting time.

| Action | Before (ms) | After (ms) |
| --- | ---: | ---: |
| Initial All snapshot | 1298.60 | 691.80 |
| September heatmap query | 83.16 | 9.58 |
| Previous calendar month | 874.76 | 10.28 |
| Next calendar month | 1165.48 | 35.22 |
| Select the 80K-event day | 2060.69 | 508.78 |
| Select Codex within that day | 2057.89 | 851.49 |

Month navigation formerly rebuilt all analytics, and queued obsolete month clicks
ran queries before being discarded. It now projects just the calendar, with
generation and data-revision guards. Heatmaps use exact indexed local-day SUMs;
day-only selection uses SQL aggregates instead of hydrating raw events. Queries
contained in one local day omit unnecessary per-event UTC slice expressions, and
identical tool aggregates are reused within a snapshot build.

Observed verification: 303 focused Swift tests passed, including full-snapshot
parity across day/period/tool/input scopes, rapid scope changes, mutation before
month navigation, hidden-tool history, DST and partial boundaries, and database
failure behavior. These are single-machine synthetic store timings, not visible
popover/frame measurements or a production performance guarantee. A day with
80K events still requires bounded SQL aggregation; tool filtering builds filtered
and unfiltered analytics. Future optimization should profile those aggregates
before introducing additional indexes, persistent rollups, or snapshot caches.

## Hook cost and reduction criteria

This section defines comparison evidence for the existing integration. It adds
no collector, settings, runtime hook, pricing catalog, or usage-event fields.
Keep hook execution overhead, emitted context, recorded usage, and estimated API
cost as separate measurements. A classification correction changes attribution;
it does not establish a reduction in token consumption.

### Owners and measurable effects

Tao owner paths below are relative to `${TAO_HOME}`. Spill paths are relative to
this repository. Inspect current owner sources rather than historical graph
content when repeating a comparison.

| Path / behavior | What to measure | Current evidence and claim boundary |
| --- | --- | --- |
| Tao `${TAO_HOME}/scripts/workflow.py` and `${TAO_HOME}/scripts/workflow_advisory_echo.py`: prompt advisory delivery | UTF-8 output bytes per delivery, full-delivery/receipt counts, hook wall time and CPU time; exact runtime input/output separately | Same-session, unchanged rendered guidance gets a short receipt after its first delivery. The synthetic byte result below is verified. Token and monetary reductions are unmeasured. |
| Tao `${TAO_HOME}/scripts/workflow_spill.py` and Spill `scripts/spill-token-metering-setup.mjs`: safe label handoff | Local invocation count/time and workflow-label coverage | Advisory routing does not call the label writer. Explicit routes own labels; discovery actions use `if_absent`. The inspected label branch writes local metadata and exits. Better labels and fewer local helper calls do not prove lower model usage. |
| Spill `adapters/claude-code/spill-hook.py`: secondary Stop metering path | Local parse/enqueue time, exact event completeness and same-span dedup parity | Reads exact usage and queues safe records; this adapter has no model API call. Collection measures prior runtime work. Removing events or skipping subagent usage cannot count as savings. Native importer plus hook duplication must resolve to one exact span. |
| Tao workflow execution and guard hooks | Invocation count, aggregate CPU/wall time, duplicate work avoided, exact runtime usage for the complete task | Local automation may avoid repeated agent steps, but savings require a paired task baseline with unchanged gate outcomes. The prompt receipt alone does not establish that the hook process stopped running or computing the route. |
| Spill calendar/query improvements | End-to-end store-action latency on the same fixture | The preceding 100K-event results measure local UI/storage work. They provide no evidence of lower hook, model-token, or API cost. |

AGY usage collection remains the approved local active importer. A label hook is
not an AGY usage hook; no AGY Stop/lifecycle metering hook is introduced here.

### Exact output result, without token estimation

On 2026-10-03, the current Tao `workflow.py route triage` advisory CLI was called
20 times against one temporary synthetic project with `.tao` present and one
opaque session id. No prompt content, live transcript, usage store, model call,
or provider price was used. Each subprocess exited successfully.

| Quantity | Exact bytes |
| --- | ---: |
| First compact advisory delivery | 1,690 |
| Each subsequent unchanged-route receipt | 160 |
| Baseline: deliver that same compact listing on all 20 calls | 33,800 |
| Observed: one listing plus 19 receipts | 4,730 |
| Avoided output against that baseline | 29,070 |

For this fixture, repeated-call output fell by **90.5%** and 20-call output by
**86.0%**. The baseline is a controlled repeated-current-listing counterfactual,
not a measured historical app version. These percentages describe UTF-8 bytes
only. Do not convert bytes or characters to estimated tokens, infer a dollar
amount, or apply the percentage to all session input. Earlier guidance can
remain in model context and be read again through a runtime cache.

The receipt depends on session identity, rendered-guidance digest, and readable
delivery state. A new session, changed listing, missing state, or cache failure
causes full delivery; remembered-session eviction can also cause redelivery.
After context compaction, the receipt exposes a reread path; do not treat cached
delivery state as proof that the agent still holds required guidance. Gate
requirements and missing/blocking guidance must remain intact in comparisons.

The existing `${TAO_HOME}/tests/test_workflow_advisory_echo.py` cases were inspected for
these boundaries. Its aggregate unittest command was rejected before execution
because it names the protected Tao checkout. It is not reported as a passing
suite. The measured claim is limited to the successful isolated 20-call fixture.

### Token and price baselines

Use exact runtime/store values `F` (fresh input), `W` (cache-write input), `R`
(cache-read input), `U` (unclassified input), and `O` (output). Raw input is
`I = F + W + R + U`, and raw total is `I + O`. Reasoning output is already a
subset of `O`; do not add it again. Do not infer any missing split from content.

The existing [stats accounting owner](../../scripts/spill-token-metering-stats-accounting.mjs)
and [raw/accounting contract](../specs/prd/token-metering/local-collection.md)
define the available comparisons:

| Metric | Calculation | Interpretation |
| --- | --- | --- |
| Raw usage | `I + O`, plus event count and model/task/stage totals | Exact consumption baseline; retains all cache reads. |
| Input coverage | `(F + W + R) / I` | Publish alongside event accounting coverage and `U`; zero input has no meaningful ratio. |
| Cache-read share | `R / I` | Share of all recorded input, distinct from share of classified input. |
| Fresh + output | `F + O` | Exact subtotal; excludes cache input and unclassified input. Incomplete accounting is not a complete workload comparison. |
| Reference index | `F + 1.25*W + 0.1*R + O` | The existing fixed comparison convention, not provider pricing, token estimation, or billed cost. Publish excluded `U` and coverage. |
| Estimated token API cost | Sum `(F*pF + W*pW + R*pR + O*pO) / 1,000,000` across matching model/provider/rate buckets | Rates are per million tokens in one stated currency. Requires exact accounting plus applicable dated rates and tier/cache-write conditions. Unknown splits, models, or rate conditions leave the full estimate unavailable; label any known subtotal explicitly. |

Follow the [cost disclosure contract](../specs/prd/token-metering/dashboard.md):
show `Estimated cost`, preserve the reviewed price date, and disclose excluded
fees/discounts and rate conditions. No current provider rates are asserted by
this assessment. A lower reference index does not establish a lower invoice.
For a fixed subscription, report token/context efficiency separately; token
reduction alone does not establish a reduced subscription charge.

### Criteria for a reduction claim

1. Name the baseline and intervention: hook kind, safe workflow category, runtime,
   model, measurement boundary, and unit. Distinguish a measured previous version
   from a synthetic counterfactual. Do not use Claude/Codex raw-total ratios as a
   hook-saving percentage.
2. Compare matched tasks and outcomes with the same model/settings, gate checks,
   tool scope, session/context-size bucket, and accounting completeness. Keep
   cold-cache and warm-cache samples separate. First-delivery and receipt samples
   are different hook paths. Report opaque session totals and unattributed-event
   counts so one long session cannot masquerade as a runtime-wide effect.
3. For execution overhead, report invocation count, total wall/CPU time, and
   median/p95 over a disclosed repeated sample. Separate process execution from
   model/approval/network waiting; do not count overlapping wall times as elapsed
   task time. No invocation or timing reduction was measured in the byte fixture.
4. For tokens, use exact approved runtime metadata for the complete paired task.
   Whole-task totals do not provide exact per-hook attribution unless the runtime
   exposes that boundary. Report raw input/output, accounting coverage, cache
   mix, and average/peak raw input per event as the context-size proxy. Bytes
   and reduced manual calls are insufficient evidence of token savings.
5. For every measured quantity, compute `delta = baseline - after` and
   `reduction_percent = 100 * delta / baseline`. Preserve negative reductions
   as regressions. If baseline is zero, publish the absolute delta and an
   unavailable percentage. Apply the formula separately to bytes, tokens,
   local time, reference index, and estimated API cost.
6. Accept an optimization only with unchanged required guidance, authorization,
   gate outcomes, event completeness, and exact-span identity. Keep metering
   hooks, fallback labels, explicit workflow labels, and setup references.
   Losing records, hiding unknown input, or changing models/workloads is not
   evidence of hook optimization.

Retain only safe enum categories, numeric measurements, timestamps, approved
model ids, and opaque ids for usage comparison evidence. Do not create a new
hook telemetry payload or store prompt/response/command text, paths, source
content, repo/branch names, or conversation titles to explain savings. Runtime
usage events retain their existing strict allowlist. A future exact-token or
price comparison needs its own approved runtime evidence; current hook token
and monetary savings remain **unmeasured**, rather than zero or an estimate.

## Claude hook processing follow-up

The Python hook's label lookup previously reopened and decoded the complete
label timeline for each emitted event. A lazy snapshot now streams only safe
label fields once per invocation and orders them by update time. Main, history,
and subagent batches share it; a new invocation reloads the timeline. Inclusive
validity windows, overlapping intervals, equal-update ordering and exact event
identity remain covered. There is no persistent cache or new polling loop.

The transcript reader also retains incomplete JSON/UTF-8 tails instead of
committing their byte cursor. Complete final JSON without a newline still
imports once. An unchanged file at the saved offset avoids opening the
transcript. Stop processing checks both known subagent directory layouts even
when the main transcript has no delta; date filtering does not exclude old
child history. These collection fixes can increase recorded usage by including
previously missed records, which must not be reported as a cost regression.

The independent synthetic comparison used the captured pre-change adapter and
the same 200-event, 1,000-label-row batch. Seven paired runs alternated execution
order. Fixture creation was excluded, enqueue used an isolated capture callback,
and emitted event/accounting digests matched for every sample.

| Measurement | Previous adapter | Canonical correction | Bundled correction |
| --- | ---: | ---: | ---: |
| Median instrumented processing (ms) | 469.263 | 4.339 | 4.284 |
| p95, nearest rank over 7 samples (ms) | 476.285 | 4.680 | 4.766 |
| Label timeline opens per batch | 200 | 1 | 1 |
| JSON loads per batch | 200,200 | 1,200 | 1,200 |

Canonical processing time fell by **99.1%** in this fixture. This measures local
instrumented history-payload processing, including Python counters; it excludes
process startup, native collection, app rendering, real inbox I/O and model
execution. It does not establish a whole-hook/UI speedup or token/API savings.
The snapshot still searches intervals linearly when no recent entry matches;
additional indexing needs a measured workload rather than a persistent cache
introduced without an invalidation contract.

The reusable [isolated regression runner](../../scripts/verify-claude-hook-incremental.py)
checks both source copies and is invoked by the existing token-metering smoke
path. Its [subject-owned test package](../../scripts/claude_hook_tests) separates
safe fixtures, transcript/queue cases, child discovery, label windows and the
optional benchmark; the same 48 cases are also exposed through unittest loading.
Eight original defects were intentionally reproduced against the captured
baseline before the fix. Fixtures cover partial tails, complete unterminated
records, malformed terminated rows, persistent indices, unchanged EOF, child
history, safe label windows and fresh-invocation reload. All fixture paths and
app-owned destinations are temporary; no real usage store or transcript is read.

The final delivered-resource check found a separate packaging defect: recursive
bundle discovery selected an older scratch release despite the active release
containing the corrected adapter. App bundling now uses the resource bundle
beside the just-built executable through `.build/release`. The existing smoke
path compares the complete adapter tree in the main app and nested dashboard,
including both SwiftPM bundle copies, against the resource sources. An old
build directory can no longer silently provide different metering code.

Verification: all 48 isolated Claude regression cases passed, together with the
complete token-metering smoke path (including 31 Codex incremental assertions
and 32 contract assertions), app rebuild, all four delivered adapter-tree
comparisons, project code gates and documentation validation. The built local
app contains these corrections; installed user-level hooks are a separate setup
surface and are not refreshed by a build.
