# AI Usage Limits PRD

## Document Contract

- Status: draft
- Audience: product, design, engineering, QA, privacy, and release maintainers
- Purpose: define how Spill shows each AI tool's remaining usage allowance
  (rate-limit percentage, credits, and reset countdowns) alongside the usage
  totals it already meters
- Source of truth: this document owns limit-data acquisition, freshness,
  estimation policy, display surfaces, and acceptance for usage limits
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md),
  [Token Metering Dashboard](token-metering/dashboard.md),
  [Privacy and Observability](privacy-and-observability.md)

## Goal

Spill already answers "how much did I use?"; this surface answers "how much do
I have left, and when does it reset?" — the number users actually check before
starting a long agent run. Each tool exposes this differently, so Spill shows
the best locally available signal per tool and is explicit about its quality
instead of pretending all three are equal.

## Data Sources (verified on-device)

| Tool | Signal | Local source | Quality |
| --- | --- | --- | --- |
| Codex | Named limit windows (`limit_id`, `limit_name`, `used_percent`, `window_minutes`, `resets_at`) plus credits `balance`. Accounts carry a variable set — the observed reference account shows a general weekly limit and a separate model-specific weekly limit — so the set of gauges is data-driven, never hardcoded to five-hour/weekly | `~/.codex/sessions/**/*.jsonl` `rate_limits` snapshots inside `token_count` events, written on every turn; the incremental Codex importer already reads these files | Exact, server-authoritative |
| Claude Code | Two sources. The status line payload carries `rate_limits` on every render while Claude Code runs, which is the live one and the reason no manual `/usage` is needed; an installed adapter harvests it and chains whatever status line was already configured. The cached utilization below remains as the fallback for a machine with no adapter. Server-computed used percent and reset time per window (session, weekly all-model, weekly model-scoped), cached by the client only when something fetches usage — it does not refresh on its own while the tool is simply in use, so a reading ages until the next fetch | `~/.claude.json`, read-only. The payload is located by shape rather than by key name — `cachedUsageUtilization` is tried first, then top-level values are scanned for an object holding limit entries — because the client has already renamed this state once. Only `kind`, `percent`, `resets_at`, and the safe scoped model display name are decoded | Exact as of `fetchedAtMs`; snapshots tagged `client_cache`. There is no fallback: when no exact payload can be located the chip stays but reports nothing, and a content-free diagnostic records which of the two happened |
| Antigravity | Per-group window percentages are fetched live by `/usage` and are not cached locally, so no window gauge can be derived. The `modelCredits` state value is a sentinel (`availableCreditsSentinelKey`), not a user-facing balance — no credits gauge is derived from it | None found locally | No gauge; the chip renders blank |

Explicitly out of scope for this PRD: calling any vendor endpoint with the
tool's OAuth credentials. That would require credential access and network
egress that Spill's local-only metering boundary forbids. It may return later
as a separate, explicitly opt-in PRD.

## MVP Requirements

1. **Limit snapshot store**
   - A new local-only store keeps the latest limit snapshot per
     `(ai_tool, limit_key)`, where `limit_key` is the tool's own limit
     identifier when it provides one (Codex `limit_id`) and a Spill-defined
     slug otherwise (`session`, `week_all`, `week_<model_group>`, `credits`).
     Each snapshot carries `used_percent` or `remaining_credits`,
     `window_minutes`, `resets_at`, `captured_at`, a display label, and a
     `source` tag (`server_exact` or `client_cache`). The `estimated` tag
     remains only so snapshot files written before estimates were retired keep
     decoding; nothing produces it and reads filter it out.
   - Snapshots are separate from the usage-event schema; the strict
     token-usage event payload does not change.
   - Snapshot refresh piggybacks on existing collection cycles (Codex importer
     pass, AGY importer pass, panel-summary refresh). No new timers, pollers,
     or file watchers.
   - Partial writers merge **one limit at a time**, keyed by `limit_key`, so a
     payload that genuinely reports only one window does not erase another.
     Codex is the bounded exception: its newest `rate_limits` line is complete
     for one `limit_id`, so Spill atomically replaces only that `limit_id:`
     group. A `secondary: null` therefore retires the old five-hour sibling,
     while a separate named/model pool remains independent. This uses the
     existing snapshot array during the capture pass; there is no additional
     cache, timer, watcher, or persisted scope field.
   - Age-out runs on each limit's own retention clock: two windows, floored at
     seven days, so a limit removed by a plan change disappears while a tool
     nobody used this week keeps its chip.
   - On conflict the newer reading wins, because every reading is now exact.
2. **Codex exact gauges**
   - The Codex session importer captures the newest `rate_limits` snapshot per
     `limit_id` during its incremental pass and stores one entry per window it
     finds (using `limit_name` as the pool label), plus credits when present.
     New limit names appear as new gauges without a code change. Within a
     present `limit_id`, a missing/null sibling is removed immediately because
     the payload is complete for that group; an entirely absent independent
     group retains its own reading until refreshed or aged out. Accounts
     differ in which windows exist at all — a plan with no five-hour window
     sends `secondary: null` — so that null is authoritative data, not a
     capture failure.
   - Remaining percent renders as `100 − used_percent`. Countdown text derives
     from `resets_at` at render time. When `resets_at` has passed and no newer
     snapshot exists, the gauge renders as replenished (100%) with a
     "as of <captured_at>" hint rather than a stale countdown.
3. **Claude gauges — exact only, from whichever source is fresher**
   - The status line adapter writes the numbers it was handed to a small file;
     `TokenUsageClaudeStatuslineCapture` reads it and merges only when its
     reading is newer than what the cached-utilization capture stored, so the
     fresher source wins rather than whichever capture ran last. Both mint the
     same limit keys, so a tool has one chip either way.
   - Status line readings are tagged `server_exact`, not `client_cache`. That
     tag records whether a source keeps writing while the tool runs, not who
     computed the number, and it is what allows a closed window to resolve to
     its post-reset value instead of withdrawing its percentage.
   - Primary: `TokenUsageClaudeLimitCapture` reads the client-cached
     utilization limits (session, weekly all-model, weekly model-scoped) and
     stores them as `client_cache` snapshots whose `capturedAt` is the
     cache's own fetch time. These are the same numbers `/usage` shows,
     including reset times, so no "~" badge applies.
   - The client owns that state's shape and has already changed it once, which
     silently demoted every Claude gauge to an estimate with nothing recording
     it. So the payload is located **structurally**: the known key is tried
     first, then top-level values are scanned in sorted key order for an object
     carrying limit entries. A rename degrades to "found it elsewhere", not to
     silent estimates.
   - Entries are recognised by shape rather than by the vendor's names for
     them: a percentage plus a reset moment is a window gauge, which admits a
     renamed window while still excluding the spend and credit rows that share
     the array. A recognised `kind` keeps its established key, label, and
     window length; an unrecognised one becomes a gauge with no window length,
     so it lists in the popover instead of claiming a chip slot.
   - Entries whose reset time has passed are **kept**, not dropped — the store
     resolves a closed window to its post-reset value (see Freshness below).
   - Every pass writes a content-free diagnostic
     (`token-metering/diagnostics/claude-limit-capture-last.json`) holding only
     fixed booleans, counts, and a timestamp: whether the state file was found
     and parsed, whether a utilization payload was located, whether it was
     found by structural scan, and how many limit entries and windowed limits
     resulted. No paths, keys, or inspected values are stored. This is what
     makes "the exact source moved" distinguishable from "no exact source
     exists".
   - No fallback when no exact reading can be located. A gauge computed from
     Spill's own history could only express a fraction of the user's own past
     burn, which is a different quantity from the vendor limit percentage the
     chip appears to report; shown beside a real server number in identical
     units it reads as fact and misleads. The chip stays and reports nothing.

4. **Antigravity gauges**
   - No window gauge, and no chip. Antigravity fetches its percentages live and
     persists none of them, so a blank chip there would read as "not yet" when
     it means "never". It is left out of the limits row rather than shown
     empty, and is not excluded anywhere else in the dashboard.
   - This is a display rule, not a capability removal: Antigravity is not
     special-cased in capture or storage, and the moment a real Antigravity
     reading exists its chip appears with no code change.
   - No credits gauge. The `modelCredits` state value decodes, but its key
     (`availableCreditsSentinelKey`) marks it as an internal sentinel and the
     user confirmed Antigravity's own UI exposes no credits balance. Showing
     it misread an implementation detail as an account fact; it was removed.
5. **Display surfaces — two surfaces, graduated detail, one visual language**
   - The shared visual language is a **remaining-ratio ring**: a circular arc
     filled by the remaining fraction, colored by threshold only (default tint
     above 20% remaining, warning at ≤ 20%, critical at ≤ 5%). Rings never
     carry embedded numbers; the percent, limit name, reset time, source
     badge, and captured-at age live in the adjacent text or tooltip
     appropriate to each surface.
   - **Token metering dashboard (most detail)**: a single-row "Limits" strip
     directly under the header — one compact chip per tool, each slot with
     its own ring, remaining percent (`~` prefix on estimates), and reset
     stamp when one is known (`5h ~31% (20:00) · Wk 29% (8/8)`).
   - Slots are **derived from the windows present in the data**, shortest
     window first, capped at two per chip. Ordering by window length is the
     point: a "most constrained" headline made every tool read on a different
     basis and was unintelligible. But the pair itself is not fixed — hardcoding
     `5h` then `Wk` fought the data, because a plan whose only window is weekly
     has no five-hour limit to draw and a plan change rewrites which windows
     exist. Window labels are derived from `window_minutes` (`300` → `5h`,
     `10080` → `Wk`, `1440` → `1d`), so a window nobody hardcoded still renders.
   - When several limits share a window, the unscoped limit represents the slot
     so chips stay comparable across tools; among unscoped peers the tightest
     one wins. For Codex, the default `codex:` group is the account-wide pool;
     every other `limit_id:` is a named/model-specific pool. Scope is computed
     from this existing key convention instead of stored as another field. If
     a named pool is the only limit for a window, its chip slot keeps both the
     pool identity and time basis (for example `GPT-5.3-Codex-Spark Wk 100%`);
     it never falls back to an ambiguous plain `Wk`. Displayed remaining
     percents floor rather than round — 99.8% remaining reads "99", never a
     false "100". Extra named limits, unwindowed limits, and credit balances
     appear as a `+n` indicator; clicking the chip opens a popover listing
     every limit for that tool with countdowns, source badges, and captured-at
     freshness. No large card.
   - **Compact panel (medium)**: the existing AI-section tool rows gain a
     trailing ring plus a short percent (for example `Codex 1M ◕40%`). No new
     rows; details stay in the dashboard.
   - Menu bar: out of MVP; revisit after the dashboard and compact-panel
     surfaces prove useful.
6. **Freshness and trust**
   - Every source here is passive: each gauge comes from a file the tool
     itself writes while it runs, so nothing refreshes while a tool sits
     unused. That is not a polling defect and cannot be fixed by polling
     harder; a live reading would need a network call to the vendor's usage
     endpoint with the user's credentials, which the local read-only privacy
     contract does not permit. The answer is an honest **as-of** display, not
     a fabricated current one.
   - A gauge is therefore always a reading "as of" a moment. Chips state that
     age once it exceeds 30 minutes, and dim once the reading is older than
     the window it describes and so can no longer describe the current one.
   - `captured_at` is the moment the reading was **true**, never the moment
     Spill scanned for it: Claude's cache fetch time (`fetchedAtMs`) and the
     Codex session line's own timestamp. Stamping the scan time would make
     every server-exact gauge look permanently fresh however long ago the tool
     last ran, which is exactly what the as-of display exists to prevent. Only
     estimates are stamped now, because an estimate genuinely is computed now.
   - **Closed windows resolve locally instead of disappearing.** Once a
     window's `resets_at` has passed, its allowance is known to have been full
     again at that moment — derivable exactly, with no source needed. The
     gauge is re-stamped at the reset moment, marked `window reset`, and
     renders 100% remaining. It claims **no** next reset time, because a
     session window opens on first use rather than on a clock, so the next one
     is not derivable. Dropping these is what used to make a chip vanish
     whenever a tool sat unused.
   - Every gauge exposes its `captured_at` age on hover/tooltip, alongside
     whether it was locally reset.
   - Ring thresholds (shared across both surfaces): remaining ≤ 20%
     renders in the warning tint, ≤ 5% in the critical tint, matching
     dashboard tint conventions.
   - A tool with no snapshot and no usage renders nothing (no empty gauges).

## Privacy

- Snapshots contain only numeric percentages, credit counts, window lengths,
  timestamps, and enum labels. No prompts, transcripts, commands, paths, or
  account identifiers are read or stored; the AGY parser extracts numeric
  varints only.
- All reads are read-only and local. No network, no credentials, no new
  daemons. Snapshots stay local-only and are excluded from any usage-event
  sync payload.

## Defaults and migration

| Concern | Decision |
| --- | --- |
| Feature flag | Limits strip on by default in the dashboard; compact-panel rings render whenever a snapshot exists (they add no space, so no separate toggle) |
| New settings | `limitGaugeClaudeWindowTokens` (optional user-entered limits), `limitGaugeAntigravityPlanCredits` (optional) |
| Schema | New local snapshot store; `token_usage_events` unchanged |
| Estimation | No estimated gauge exists. A percentage is shown only when a tool reported one; otherwise the chip reports nothing |

## Acceptance criteria

- With recent Codex activity, the dashboard shows one gauge per named Codex
  limit whose labels, percentages, and reset times match Codex `/status`
  output at capture time (including model-specific weekly limits), with
  countdowns that tick without any new polling loop.
- When the newest complete Codex payload changes `secondary` to null, the old
  five-hour sibling disappears without deleting another named pool. When an
  account-wide and a named/model-specific pool share a weekly window, the
  account-wide value represents the slot; a named-only slot includes its pool
  name beside `Wk` or the applicable window label.
- With a Claude usage payload cached, the Claude gauge's percentages equal the
  ones `/usage` prints for the same windows, digit for digit.
- With no Claude payload cached, the Claude chip renders but reports no
  percentage, and nothing is substituted for the missing reading.
- With Antigravity installed and no Antigravity reading available, no
  Antigravity chip appears in the limits row; supplying one restores it.
- Quitting the tools, disconnecting the network, or deleting a snapshot store
  never breaks metering; limits are additive and fail silent.
- All gauges re-render countdowns through existing dashboard and compact-panel
  update paths; Instruments shows no new timer sources.

## Open decisions

- Whether Codex credits (`balance`) deserve their own gauge or stay a tooltip
  detail (MVP: tooltip detail).
- Antigravity `/usage` per-group server percentages via opt-in authenticated
  fetch — deferred to a separate PRD if users ask for exact AGY windows.

## Phasing

1. Phase 1: snapshot store + Codex exact gauges + dashboard Limits strip.
2. Phase 2 (superseded): estimated Claude/AGY gauges and an AGY credits gauge shipped here and were later removed — the credits value was an internal sentinel, and the estimated percentages were not the limit percentages they appeared to be.
3. Phase 3: compact-panel rings.
