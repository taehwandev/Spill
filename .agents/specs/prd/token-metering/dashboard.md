# Token Metering Dashboard PRD

## Document Contract

- Status: active
- Audience: product, design, engineering, QA, and support maintainers
- Purpose: define token usage presentation across local dashboard surfaces
- Source of truth: this document owns token dashboard UX and presentation settings
- Related: [Spill PRD index](../../prd.md), [Spill ARD](../../ard.md),
  [Local Token Collection](local-collection.md), [AI Status](../ai-status.md)

## Tool Visibility And Presentation Requirements

- The Preferences "AI tool visibility" list must always offer Codex, Claude
  Code, and Antigravity/AGY show/hide toggles by default. It must not depend on
  local runtime installation, Spill setup files, adapter hooks, importers, or a
  prior Spill installation.
- The visibility toggle is the shared display preference for AI dashboard
  usage, dashboard agent-status cards, compact-panel AI cards, and menu-bar
  token totals. It does not affect saved records or local collection.
- Runtime installation and adapter connection state remain available through
  Setup and history-import UI.
- Visible agent-status cards keep the canonical order Codex, Claude Code, then
  Antigravity/AGY on every refresh. Detected runtime status replaces the
  matching neutral display state by tool identity and never reorders the cards.
- Display-only agent states must not be treated as runtime installation
  evidence. Setup, adapter diagnostics, and history-import availability use the
  raw detected-runtime state.
- The local dashboard groups usage into human-readable Work Items derived from
  safe labels, not raw run ids.
- Work Items may be scoped by opaque local folder/project ids. UI labels use
  short opaque labels such as `Folder abcd1234`, never real paths, repository
  names, project names, or command-derived names.
- Dashboard period, tool, and folder filters apply to both charts and Work Items.
  Folder filters keep a stable label-based order instead of moving with totals.
- Raw `run_id` and `span_id` values appear only in diagnostics or collapsed
  technical details.
- Local aliases, if supported, are local-only display metadata and do not change
  totals, safe labels, event payloads, or cloud-safe schemas.
- Missing model, source, or latency values are labeled unavailable or
  runtime-total fallback instead of being presented as meaningful zeroes.

## Usage Statistics And Accounting Presentation

- Token usage surfaces treat total tokens, input tokens, output tokens, event
  count, average event size, peak event size, model breakdown, task breakdown,
  stage breakdown, and workflow label coverage as the primary analytical statistics.
- Dashboard surfaces distinguish raw usage totals from accounting buckets and
  workflow labels. Input/output totals answer token direction; task and stage
  answer workflow grouping; accounting buckets explain exact runtime-reported
  input splits.
- If an accounting split is unavailable, input remains valid raw usage and is
  shown as unclassified or unsplit instead of being inferred from content.
- Token detail categories such as system, user, history, repo context, tool
  output, generated output, and unknown are secondary measurement-quality
  statistics and are shown only from exact runtime or adapter counts.
- The `unknown` token detail bucket means exact attribution was unavailable. It
  is not an AI judgment, semantic classification, or proof that user input alone
  consumed those tokens.
- Cost estimates are computed from model-specific pricing and exact accounting
  buckets, not a flat total-token multiplier.
- All cost UI says `Estimated cost`, not billed or actual cost. The web pricing
  catalog is a dated application snapshot reviewed against the official OpenAI
  model pricing (<https://developers.openai.com/api/docs/models> and
  <https://openai.com/index/gpt-5-6/>), Anthropic pricing
  (<https://platform.claude.com/docs/en/about-claude/pricing>), and Google
  Gemini API pricing (<https://ai.google.dev/gemini-api/docs/pricing>). The
  disclosure shows its review date and notes that batch discounts, long-context
  tiers, cache-storage duration, tool fees, taxes, and negotiated rates may
  differ from an invoice. Unknown models show an unavailable estimate rather
  than a fabricated fallback price.

## Usage-Input Scope Setting

- Token Meter settings offer persisted `Include cache` and `Fresh only` choices.
  `Include cache` is the default.
- `Fresh only` changes dashboard KPIs, period totals, AI-tool filters and
  distribution, model and project usage, trends, calendar totals, Work Type,
  Work Step, Work Item totals and shares, the compact panel headline, and the
  clock-area AI token value to exact uncached input plus unchanged output.
- Daily and all-time menu bar modes use the same scope. Input without an exact
  accounting split is not guessed and is not counted as fresh.
- The setting includes an accessible information button that explains the exact
  data boundary.
- Changing the scope updates the running main menu bar process, compact panel,
  and separate dashboard helper immediately without restart, reopen, manual
  refresh, or Private Usage Upload sync.
- The scope does not filter raw input accounting, source-detail rows, raw events,
  stored totals, or sync totals. Workflow coverage remains an event ratio.
- The raw input accounting card always shows the complete available
  fresh/cache-write/cache-read/unsplit breakdown and has no scope control.
- The local app scope is a device-local presentation preference and does not
  alter web cost estimates. A web estimator may persist its own cost scope, but
  both modes derive from the complete synced accounting aggregate and provider rates.

## Dashboard UX Requirements

- Default time range is `Today`, with explicit `7 days`, `30 days`, and `All` controls.
- Default token content includes all first-class local agent tools except those
  hidden by the user's visibility setting, regardless of local installation.
- Installation eligibility is separate from token display. Legacy `unknown`,
  optional OpenAI SDK events, and stored rows for an uninstalled runtime remain
  stored and belong behind diagnostics or an advanced filter.
- The first read answers whether usage was large, whether cost came mostly from
  input or output, which model/tool/work type/stage dominated, and whether
  workflow labels covered the selected records.
- Raw input accounting appears separately from token detail and workflow labels.
  Copy explains that cache discounts and cost weighting belong in cost display,
  not raw storage or default totals.
- The accounting card keeps its information affordance but no display filter.
  The scope control belongs in Settings > Token Meter.
- Top AI tool tabs may show each tool's share of the current All-tool scope, but
  share remains secondary to the tool name.
- The filter bar provides a Segmented Picker (`Tokens` versus `Share %`) for the
  dashboard token unit display mode.
- In `Tokens` mode, the primary detail shows token count and the secondary label
  shows share percentage. In `Share %` mode, the order is reversed.
- First-class tools use one consistent color identity across panel summary,
  tool tabs, distribution rows, tool cards, and process status: Codex teal,
  Claude orange/coral, and Antigravity/AGY blue.
- Summary cards prioritize total, input, output, event count, average event size,
  and peak event size before token detail categories.
- Workflow label coverage appears as a measurement-quality signal. Usage remains
  valid when labels are absent or fall back to `uncategorized/summarize`.
- Work item rows are selectable and update a safe detail panel with totals,
  event count, tool, model, stage, token detail, time range, label source, and
  optional local alias.
- Every summary, Work Item, token detail, model, and technical detail surface has
  an information affordance explaining counted, inferred, and unavailable data.
- Dashboard headers do not repeat counts already shown in metric components.
- Token detail charts are labeled optional detail quality. When most detail is
  unknown, the UI directs users to input/output totals and label coverage.
- Loading, empty, onboarding, and normal states keep the same major layout
  regions so the UI does not jump during refresh.
- UI copy states that exact counts are required and estimates should not be sent.

## Acceptance

- The dashboard shows combined usage and filters it by safe AI tool labels.
- Agent-facing and dashboard summaries explain usage primarily through raw
  totals, event size, model, task, stage, and workflow-label coverage.
- Token detail is presented as optional exact detail and `unknown` as
  unavailable attribution.
- Work Item rows update a safe detail panel.
- The compact panel headline follows the persisted usage-input scope immediately,
  while workflow/detail subtitles and grouped rows remain cache-inclusive.
- Dashboard KPI, period, tool, model, project, trend, calendar, Work Type, Work
  Step, and Work Item values consistently use the selected scope. Workflow
  coverage, source detail, and raw accounting remain cache-inclusive.

## Verification

- Verify supported-tool visibility and canonical ordering independently from installation.
- Verify every scope-sensitive surface updates immediately and consistently.
- Verify raw accounting, storage, and sync remain cache-inclusive.
- Verify loading, empty, onboarding, and normal layouts retain their major regions.
