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
  [Top Glance Surface](top-glance-surface.md),
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
| Claude Code | None persisted locally (`/usage` renders live server data and discards it) | Spill's own imported per-turn usage: exact five-hour-window and weekly consumption computed from `token_usage_events` | Consumption exact; the limit denominator is an estimate (see Estimation policy) |
| Antigravity | Credits balance cached by the client; per-group window percentages are fetched live by `/usage` and are not cached locally | `state.vscdb` → `antigravityUnifiedStateSync.modelCredits` (base64 protobuf varints: available credits, minimum-per-use), read-only; plus Spill's own imported AGY usage for estimated windows | Credits exact-as-cached; window gauge estimated |

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
     `source` tag (`server_exact`, `client_cache`, `estimated`).
   - Snapshots are separate from the usage-event schema; the strict
     token-usage event payload does not change.
   - Snapshot refresh piggybacks on existing collection cycles (Codex importer
     pass, AGY importer pass, panel-summary refresh). No new timers, pollers,
     or file watchers.
2. **Codex exact gauges**
   - The Codex session importer captures the newest `rate_limits` snapshot it
     encounters during its incremental pass and stores one entry per named
     limit it finds (using `limit_name` as the display label), plus credits
     when present. New limit names appear as new gauges without a code
     change; limits absent from the newest snapshot age out.
   - Remaining percent renders as `100 − used_percent`. Countdown text derives
     from `resets_at` at render time. When `resets_at` has passed and no newer
     snapshot exists, the gauge renders as replenished (100%) with a
     "as of <captured_at>" hint rather than a stale countdown.
3. **Claude estimated gauges**
   - Spill mirrors the shape of Claude's own usage screen: a five-hour session
     window, an all-model weekly window, and per-model-group weekly windows
     where Spill's per-model events allow it (model ids map to display
     groups). Consumption is computed exactly from Spill's imported Claude
     events (input+output totals, cache included, matching the
     comparable-totals contract); only the denominators are estimated.
   - The denominator comes from, in priority order: a user-entered limit in
     Preferences, else the high-water mark of window consumption Spill has ever
     observed for that window. Gauges carry an "estimated" badge; there is no
     unlabeled estimate anywhere.
   - Five-hour window boundaries use fixed-window chaining, matching the
     tools' real session semantics: a window opens at the first usage after
     the previous window expires and resets a fixed interval later. The
     countdown is that expiry (`window start + window length`). Any usage gap
     longer than the window re-anchors the chain, so the stamp stays honest.
     When no window is active the gauge reads empty and shows no countdown.
     Hour-bucket granularity may shift the reset by up to an hour; the
     mandated "~" badge covers this.
   - Weekly estimated gauges are rolling seven-day windows and never show a
     reset stamp: week-long usage gaps do not occur, so a chained weekly
     anchor would just replay whenever local collection began and produce a
     confidently wrong date. A wrong date is worse than no date.
4. **Antigravity gauges**
   - Credits: the AGY collection pass reads `modelCredits` read-only, parses
     the available-credits varint, and stores it as a `client_cache` snapshot.
     Parse failures are silent-skip with a content-free local diagnostic
     boolean; the gauge simply does not render. The parser must tolerate
     unknown fields and never write to the database.
   - Windows: same estimated five-hour/weekly gauge machinery as Claude, fed by
     imported AGY usage, labeled estimated.
   - When the user has verified the credits reading against Antigravity's own
     UI once (a Preferences confirmation), the credits gauge may show a percent
     against a user-entered plan total; until then it shows the raw balance.
5. **Display surfaces — three surfaces, graduated detail, one visual language**
   - The shared visual language is a **remaining-ratio ring**: a circular arc
     filled by the remaining fraction, colored by threshold only (default tint
     above 20% remaining, warning at ≤ 20%, critical at ≤ 5%). Rings never
     carry embedded numbers; the percent, limit name, reset time, source
     badge, and captured-at age live in the adjacent text or tooltip
     appropriate to each surface. The more permanently visible the surface,
     the less it shows.
   - **Token metering dashboard (most detail)**: a single-row "Limits" strip
     directly under the header — one compact chip per tool rendering the same
     fixed window slots in the same order (`5h`, then `Wk`), each slot with
     its own ring, remaining percent (`~` prefix on estimates), and reset
     stamp when one is known (`5h ~31% (20:00) · Wk 29% (8/8)`). A fixed slot
     order is the point: a "most constrained" headline made every tool read
     on a different basis and was unintelligible. Extra named limits and
     credit balances appear as a `+n` indicator; clicking the chip opens a
     popover listing every limit for that tool with countdowns, source
     badges, and captured-at freshness. No large card.
   - **Compact panel (medium)**: the existing AI-section tool rows gain a
     trailing ring plus a short percent (for example `Codex 1M ◕40%`). No new
     rows; details stay in the dashboard.
   - **Glance (minimal, always visible)**: the remaining-ratio ring is drawn
     on the circumference of the existing 14-point tool icon circle, adding
     zero width to the strip. The most constrained limit for that tool drives
     the ring; hover shows `label percent left · resets <time>`. No separate
     Limit segment; the existing single Glance timeline drives countdown and
     ring re-rendering at one-minute granularity with no second schedule.
   - Menu bar: out of MVP; revisit after the three surfaces prove useful.
6. **Freshness and trust**
   - Every gauge exposes its `captured_at` age on hover/tooltip.
   - Ring thresholds (shared across all three surfaces): remaining ≤ 20%
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
| Feature flag | Limits strip on by default in the dashboard; panel and Glance rings render whenever a snapshot exists (they add no space, so no separate toggle) |
| New settings | `limitGaugeClaudeWindowTokens` (optional user-entered limits), `limitGaugeAntigravityPlanCredits` (optional) |
| Schema | New local snapshot store; `token_usage_events` unchanged |
| Estimation labeling | `estimated` badge is mandatory wherever the denominator is not server-provided |

## Acceptance criteria

- With recent Codex activity, the dashboard shows one gauge per named Codex
  limit whose labels, percentages, and reset times match Codex `/status`
  output at capture time (including model-specific weekly limits), with
  countdowns that tick without any new polling loop.
- With Claude usage imported, the Claude gauge's consumption numerator equals
  the sum Spill's own dashboard reports for the same window, and the gauge
  carries the estimated badge.
- With Antigravity installed, the credits gauge matches the value Antigravity's
  own UI shows (verified manually once), and a corrupted or unreadable
  `modelCredits` value results in no gauge and no crash.
- Quitting the tools, disconnecting the network, or deleting a snapshot store
  never breaks metering; limits are additive and fail silent.
- All gauges re-render countdowns through the existing Glance/dashboard
  schedules; Instruments shows no new timer sources.

## Open decisions

- Whether Glance ticker mode needs any limit-specific behavior beyond the icon
  ring, which already travels with whichever module is on screen (MVP: no).
- Whether Codex credits (`balance`) deserve their own gauge or stay a tooltip
  detail (MVP: tooltip detail).
- Antigravity `/usage` per-group server percentages via opt-in authenticated
  fetch — deferred to a separate PRD if users ask for exact AGY windows.

## Phasing

1. Phase 1: snapshot store + Codex exact gauges + dashboard Limits strip.
2. Phase 2: Claude/AGY estimated gauges + AGY credits + Preferences entries.
3. Phase 3: compact-panel and Glance rings.
