# Spill ARD

Architecture Requirements and Decisions.

## Architectural Goal

Build a compact, native macOS utility that is reliable enough to distribute and extensible enough to add system, AI, app, and window providers.

The architecture must avoid fragile menu bar manipulation and instead treat the Spill Panel as the primary product surface.

## Major Decisions

### ARD-001: No Spacer Architecture

Decision:

Use small functional status items only. Do not create giant or invisible spacer
status items.

Rationale:

Modern macOS can hide or clip status items when space is constrained. Apple documents that status items are not guaranteed to be available at all times. Spacer behavior is therefore not a stable product foundation.

Implications:

- Spill cannot promise to physically move hidden items out from behind the notch.
- Spill must provide value through its panel and providers.

### ARD-001A: Functional Menu Bar Status Surface

Decision:

Use one small horizontal `NSStatusItem` as the default menu bar surface. Compact
icon/value rendering and functional group splitting are independent user
preferences, not automatic defaults.

When split groups are enabled, Spill may create separate small `NSStatusItem`
instances:

1. Main trigger, including optional Caffeine state.
2. System glance values such as CPU, memory, and opt-in Network RX/TX.
3. AI glance values such as local token usage.

The Main trigger is the survival priority and remains the panel entry point.
Caffeine remains part of the main surface. Only compact split mode may render it
as trigger state or a compact badge on the Main trigger instead of a separate
chip in the main item. System and AI values use their own compact status items
only when the user enables split groups.
`MenuBarTriggerIconStyle` owns the Main trigger mark: the droplet remains the
default, and the symbolized Spill S mark is an alternate user-selected mark.

Rationale:

macOS does not expose a reliable status item width negotiation API when system
extras such as Now Playing, iPhone, call, microphone, screen sharing, or other
Apple-managed indicators appear. Spill therefore cannot wait for an exact
"space is running out" callback. The default must remain predictable, while
optional split groups let users who prefer survival-priority behavior allow
System and AI values to be moved, hidden, or reordered by macOS/user menu bar
behavior.

Rules:

- The default experience uses one horizontal status item and does not force
  compact icon/value rendering.
- Split groups are opt-in. Compact rendering is opt-in. Either option can be
  enabled independently.
- Caffeine must not create a separate `NSStatusItem`; it is part of the main
  surface.
- The Main trigger opens the Spill Panel. Caffeine details and actions remain
  available through tooltip, menu, or panel UI when compact mode makes the badge
  itself too small for reliable direct interaction.
- System and AI values must share the same provider stores and refresh cadence
  as the Main app state instead of starting independent timers.
- `MenuBarStatusSummary` carries formatted text plus semantic graph series to
  AppKit status chips. `SpillSettings` persists a presentation style per
  graph-capable metric and coordinates Off with the existing enabled-item set.
  CPU, memory, and Network can independently select Off, Text, or Chart, while
  Text and Chart are never combined in one chip. CPU and memory use one status
  series; Network uses separate receive and upload series from `SystemStatusStore`.
- When the per-metric style map is absent, settings migrate the legacy global
  `MenuBarStatusPresentationStyle` to CPU, memory, and Network. The enabled-item
  set remains authoritative, so Network stays default-off and an Off/On cycle
  preserves the metric's last Text or Chart selection.
- Horizontal and vertical chip owners reuse the same AppKit chart view. The view
  draws its own frame, background, guide, area fill, traces, and endpoint, but it
  must not sample system state, start timers, or decide whether a metric is enabled.
- CPU and memory retain fixed unit scaling. Network RX/TX share a recent-peak
  scale inside the renderer so relative traffic shape remains readable without
  changing the accessible current-rate text.
- Network menu bar support is opt-in and default off. Its receive and upload
  traces use distinct styling while tooltips and accessibility labels remain the
  non-color-only source of meaning in Chart mode.
- System and AI status items are optional display surfaces. Hiding them because
  no corresponding value is enabled must not disable the underlying provider.
- Spill cannot rely on macOS preserving item order. Functional items are a
  resilience strategy, not a guarantee that System or AI always appear in a
  precise position.

### ARD-002: Public APIs First

Decision:

Use AppKit, SwiftUI, Accessibility, ServiceManagement, and other public frameworks. Avoid private APIs such as SkyLight/CoreGraphics Services.

Rationale:

Private APIs create maintenance risk, notarization risk, and trust issues for an open-source app.

Allowed:

- Accessibility API for reading/pressing UI elements.
- Accessibility API for moving active windows.
- ScreenCaptureKit only for explicit future experiments requiring user permission.

Disallowed in MVP:

- SkyLight hooks.
- CGS private symbols.
- System Integrity Protection workarounds.
- Injection into other apps.

### ARD-003: Provider-Based Status Model

Decision:

Model UI content as providers that return small status items and actions.

Conceptual interfaces:

```swift
protocol SpillStatusProvider {
    var id: String { get }
    var title: String { get }
    func snapshot() async -> [SpillStatusItem]
}

protocol SpillActionProvider {
    var id: String { get }
    func actions() async -> [SpillAction]
}
```

Initial providers:

- `SystemStatusProvider`
- `AIStatusProvider`
- `MenuBarActionProvider`
- `WindowActionProvider`

Rationale:

This keeps the panel extensible without turning every feature into a special case.

### ARD-004: Best-Effort Menu Bar Scanner

Decision:

The AX menu bar scanner remains best-effort and asynchronous.

Rationale:

AX exposes some menu bar extras but not every hidden item. UI must not freeze or make completeness claims.

Scanner rules:

- Run off the main path.
- Cache icons.
- Time out AX calls.
- Track failure messages.
- Present detected items as candidates, not guaranteed inventory.

### ARD-005: Compact Panel Composition

Decision:

The panel is a compact composition of strips and action groups, not a page-like dashboard.

Panel sections:

1. Status Strip
2. AI Strip
3. Pinned Actions
4. Window Actions
5. Detected Items, optionally collapsed

Constraints:

- Default height target: 120-180px.
- Avoid nested cards.
- Use grouped pills and icon buttons.
- Prefer icons and concise labels.
- The root `NSVisualEffectView` owns a same-size public AppKit mask image with
  the panel's continuous 22-point rounded outline. Layer corner radius remains
  the border/compositing contract, while the effect mask clips
  `behindWindow` material itself so rectangular translucency cannot survive in
  the outer corners. The mask is regenerated when the content bounds change.

### ARD-0050: Onboarding Preview Uses Fixture Data Sources

Decision:

General dashboard/panel onboarding and local token dashboard onboarding previews
use deterministic app-owned fixture data sources. They must not delete,
truncate, overwrite, or reinterpret the user's production stores.

Rationale:

The panel and dashboards are entry points. Testing onboarding by forcing a real
store into an empty state is fragile and can hide regressions in the actual
empty, loading, and content paths. A fixture data source lets the UI behave like
optional integrations are not installed while keeping local token, settings,
menu bar, and process state intact.

Rules:

- Preview mode is UI state owned by the relevant store or screen state owner.
- Fixture records are deterministic, local-only, and clearly synthetic.
- Production stores remain the source of truth when preview mode is off.
- Preview mode must not enqueue token events, run setup hooks, alter adapter
  diagnostics, reset importer cursors, or request permissions.
- Empty onboarding copy should be rendered from preview state, not by special
  casing a real database as empty.

### ARD-005A: Token Metering Lives Inside The AI Strip

Decision:

Token metering appears as a compact summary inside the existing AI strip of the
Spill Panel. The visible menu bar trigger continues to toggle the panel. A
separate native `Spill - AI Token Metering` dashboard may exist as a detail action from that
summary, Preferences, or menus, but it must not replace the panel as the primary
surface.

Rationale:

Token metering is AI usage state, so it belongs next to the existing local AI
tool status. Putting it behind Preferences, a web dashboard, or replacing the
panel makes the feature feel like setup work instead of a usable local meter.

Constraints:

- The status item remains a single small trigger.
- Left click continues to toggle the compact Spill Panel.
- The token summary must stay compact and must not turn the panel into a large
  dashboard.
- Secondary header lines in dashboard surfaces should not repeat counts already
  represented by metric cards, status pills, or rows.
- Detail actions must not start cloud sync, auth, network upload, or content
  collection.

### ARD-005A1: AI Process Visualization Is Derived Display State

Decision:

The AI area may show a compact process-state visualization derived from the
existing local AI status provider. It is display state, not a new data
collection channel. Tool status is based on process presence and aggregate
local resource metrics, not a threshold-based "active" classifier.

Rationale:

Users need a quick answer to "how many AI tools are active?" without opening the
token dashboard. The existing local process/configuration status already has
enough safe information to render a small chart or count summary.

Rules:

- The visualization reads only normalized AI status display models already
  produced by the local AI status provider.
- Status buckets may include running, configured/ready, unavailable, and
  warning/error when those states already exist. `Running` means one or more
  matching local processes exist. `Ready` means the tool appears installed but
  no matching local process is running.
- The UI must not present a separate `Active` count derived from process
  presence or arbitrary CPU thresholds. Current activity should be represented
  by numeric CPU percentage, memory usage, and process count.
- Process metrics are aggregated per AI tool across every matching process.
  Multiple processes are expected for terminal sessions, app helpers, language
  servers, local model servers, and Electron-based tools.
- The compact card should show aggregate process metrics when available. The
  detail popover should show aggregate CPU, memory, process count, and a short
  per-process list using safe executable names, pid, CPU, and memory.
- AI process metrics should use macOS public process APIs when available rather
  than parsing lifetime-average `ps` CPU output. Per-process CPU should be
  derived from the delta of `proc_pidinfo` cumulative user and system CPU time
  between samples, where 100% means one fully used CPU core. Memory should
  prefer `proc_pid_rusage` footprint values such as `ri_phys_footprint`, falling
  back to resident size when footprint is unavailable, so the UI better matches
  Activity Monitor's default Memory column. The provider should read a broad
  command list only for candidate discovery, then call expensive per-pid metric
  APIs only for known local AI tool candidate processes. It must cache only
  numeric pid, timestamp, and CPU-time sample state needed for delta
  calculation.
- The first sample for a new process may report zero or fallback CPU until a
  later sample exists. Dashboard and panel refresh loops should provide a
  moderate visible-surface refresh cadence instead of high-frequency polling.
- First-class AI tool colors are a token metering dashboard presentation
  contract. Codex, Claude Code, and Antigravity/AGY must resolve through one
  shared color mapping used by top tool tabs, AI Tool Distribution rows, and
  agent/process status cards. The shared mapping should use Codex teal, Claude
  orange/coral, and Antigravity/AGY blue as the product identity colors. Selected
  and unselected states may vary opacity but must not change the tool identity
  color.
- The visualization must not inspect prompts, transcripts, commands, file
  paths, repository names, shell history, logs, diffs, source content, process
  argument values beyond existing safe labels, or secret-bearing config values.
- It must not execute new network calls or paid model/API calls.
- It should degrade to the existing AI status pills when no chartable state is
  available.

### ARD-005A2: Official AI Service Status Uses One Local Network Owner

Decision:

The main Spill process is the only network owner for official AI service-status
requests. The separate token dashboard helper never constructs an independent
official-status fetch path. Both processes render one app-owned local JSON
snapshot and use content-free distributed notifications for refresh requests
and cache invalidation.

Data flow:

```text
Main panel click/refresh
  -> main CloudServiceStatusStore
  -> official provider status endpoints
  -> atomic local JSON cache write
  -> status-did-change notification

Token dashboard helper click/refresh
  -> refresh-request notification (force boolean only)
  -> main CloudServiceStatusStore
  -> official provider status endpoints when stale or forced
  -> atomic local JSON cache write
  -> status-did-change notification
  -> helper reloads only a newer cached snapshot
```

Rationale:

The official status is informational display state, not account data. A single
network owner avoids duplicate three-provider request batches and prevents the
main panel and helper from retaining unrelated in-memory snapshots. The local
cache already provides the persistence needed across process lifecycles, while
notifications provide immediate invalidation without polling or cloud state.

Rules:

- The existing healthy and incident cache TTLs remain the freshness policy.
- Opening a status popover may request a stale refresh; the explicit refresh
  button may force one. No launch-time, timer-based, or background polling path
  is added.
- The refresh-request notification contains only the force-refresh boolean.
  The change notification contains no payload. The official public snapshot is
  exchanged through the existing atomic local cache file.
- The helper reloads only a snapshot with a newer `fetchedAt` value so an older
  or duplicated notification cannot roll visible status backward.
- If the main process is not running, the helper activates it without bringing
  it to the foreground, then posts the refresh request. If no newer cache
  arrives within the bounded request window, the helper keeps the previous
  snapshot and returns to a retryable idle state.
- A successful main-process cache write posts one change notification. Cache
  write failure must not create another network side effect.
- Status guidance is a pure presentation mapping over loading state and the
  cached snapshot. Healthy official services direct users to local process and
  setup checks; incidents direct users to affected official services; unknown
  or incomplete status directs users to refresh or the official status page.
- The cache and notifications must not write token usage events, telemetry,
  account records, Private Usage Upload data, web dashboard data, settings sync,
  agent-facing summaries, prompts, commands, paths, logs, or source content.

Surface impact:

- Preferences: not applicable; no setting or control changes.
- Main-process compact Spill Panel/general dashboard: affected; it owns the
  official fetch and receives the shared guidance.
- Separate `Spill - AI Token Metering` helper: affected; it requests refreshes
  and reloads cache instead of fetching directly.
- Clock-adjacent AI glance: affected only through the existing main-process
  store; no new timer or request path is added.
- Web dashboard, Private Usage Upload, sync payloads, and agent-facing
  summaries: not applicable; official service status remains local-only and is
  excluded from those contracts.

### ARD-005C: Spill - AI Token Metering Uses A Separate Helper App

Decision:

The detailed `Spill - AI Token Metering` dashboard launches as a separate bundled helper app
from the main menu bar utility. The main Spill app remains an `LSUIElement`
accessory process with one status item. The dashboard helper uses regular app
activation so it can appear in Command-Tab/Alt-Tab style app switching and own
normal window commands such as Command-Q.

Rationale:

The compact tray and the detailed dashboard have different lifecycle and focus
expectations. Keeping the detailed dashboard in a separate process avoids
turning the menu bar app into a regular foreground app, prevents Command-Q in
the dashboard from terminating the tray, and lets users switch back to the
dashboard like a normal app window.

Rules:

- The helper app reuses the same executable code path but enters a
  dashboard-only delegate when launched from the helper bundle or explicit
  dashboard mode.
- The helper delegate owns only token metering dashboard state, local store
  reads, and dashboard refresh/collector requests. It must not create a status
  item, global hotkey, menu bar scanner, sleep guard, update UI, token bridge
  server, or compact panel.
- Main app entry points for the dashboard, including panel, status menu,
  Preferences, and main menu actions, route through one launcher command.
- The launcher should activate an existing helper instance when available and
  fall back to the old in-process dashboard only when the helper bundle is
  unavailable or launch fails.
- Closing or Command-Q from the dashboard helper terminates only the helper
  process. The main Spill menu bar process continues running.
- The local store remains app-owned and token-only. The helper must not add
  cloud sync, auth, prompt logging, transcript inspection, or broad filesystem
  access.
- The launcher passes the main bundle identifier into a helper it starts. That
  launch evidence means the main app is already running, so collection and
  status refreshes post distributed notifications without calling
  LaunchServices back into the main app. A directly started helper may use the
  asynchronous `NSWorkspace.openApplication` completion path once per helper
  process, but repeated refreshes must not emit reopen requests. The helper must
  not synchronously enumerate `runningApplications` or read each application's
  bundle identifier on the main actor.
- Token metering resource and language bundles are resolved once per helper
  process and reused across SwiftUI text lookups.
- One shared dashboard window-metrics owner defines the AppKit and SwiftUI
  minimum content size (`1060×640`). The AppKit window controller owns initial
  refresh, deferred collection, and visible-window refresh-loop lifetimes;
  SwiftUI appearance owns settings/observer synchronization only.
- Release verification must exercise the visible helper window rather than the
  existing no-window lifecycle smoke alone. The render smoke forces the first
  layout/display, validates the shared minimum content size, and enforces a
  local `1500 ms` regression budget before the Sentry `2000 ms` AppHang limit.

### ARD-005B: Local Token Metering Uses App-Owned Local Receivers

Decision:

The native app owns an app-local token usage store. The default receiver is a
local event queue directory that trusted hooks and adapters can write without
opening a network port. Writers create one unique `.tmp` file per event and
atomically rename it to `.json`; Spill imports complete `.json` files into the
same `TokenUsageStore`.

Rationale:

Project-specific setup would be easy to miss. A global local queue plus a
global agent setup prompt or runtime hook lets Spill work across projects while
keeping the safety boundary explicit. A queue directory is cheaper than a local
server, avoids a persistent port, and avoids shared-file append races between
concurrent agent hooks.

Rules:

- Local receivers store only numeric token counts, timestamps, model ids, and
  opaque ids plus safe enum labels such as `ai_tool`. Sync behavior is an
  app-owned policy applied after import, not a value selected by agent hooks.
- Local queue writers must never append to a shared events file. They must write
  a unique `.tmp` file, close it, then rename it to `.json` in the same
  directory so Spill never imports partial writes.
- Local receivers must reject or ignore prompt text, responses, commands, file
  paths, repo names, branch names, commit messages, terminal output, logs,
  diffs, source content, environment values, secrets, and arbitrary extra
  fields.
- Detailed task and token category breakdowns require exact runtime usage metadata supplied
  through the safe local event contract.
- `task_type` and `stage` are extensible safe workflow slugs, not closed enums.
  Spill publishes recommended labels, but AI runtimes, workflow hooks, and
  adapters may define custom reusable categories that match
  `^[a-z][a-z0-9_]{1,40}$`.
- First-class tool comparisons use raw exact token totals. Runtime adapters must
  normalize provider-specific cache fields into comparable raw input/output
  totals before storage. For Claude Code, raw `input_tokens` means
  `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`.
  For Codex, `input_tokens` already includes cached input reads. Cost-weighted
  views may apply model-specific cache discounts later, but storage and
  default usage comparison must keep the raw exact counts.
- Dashboard presentation may aggregate local-only accounting buckets into
  display rows for fresh input, cache creation, cache read, and unsplit input.
  These rows are a display/analysis aid only. They must not alter
  `input_tokens`, `output_tokens`, `total_tokens`, event identity, workflow
  label grouping, or default tool comparisons.
- Pricing remains a presentation-layer estimate. The web repository owns the
  dated provider rate table and pins its review date in tests; the normative
  source pages are OpenAI's model catalog and GPT-5.6 announcement, Anthropic's
  standard API pricing, and Google's Gemini Developer API pricing as linked in
  the PRD. A rate refresh updates the source date, model table, estimator, and
  test fixtures together. Unknown pricing is represented as unavailable, and
  invoice-only adjustments are never inferred from token aggregates.
- `SpillSettings` persists the overview usage-input scope as a small string enum
  whose invalid or missing value falls back to `Include cache`. Snapshot
  aggregation keeps one complete raw accounting row set and separately records
  the exact uncached-input subtotal. The overview KPI projection uses raw input
  for `Include cache`, or exact uncached input for `Fresh only`, and keeps output
  unchanged. The menu bar store query applies the same projection to both daily
  and all-time AI values without changing stored totals. Unclassified input is
  never inferred as fresh. Raw accounting, stored events, and synced totals keep
  their cache-inclusive baseline regardless of this local preference. The local
  AI dashboard projects Work Type, Work Step, and Work Item aggregates from the
  selected scope without rewriting the stored event totals.
- Dashboard snapshot construction receives the selected input scope and uses a
  single exact token projection (`total_tokens` for Include cache, or
  `output_tokens + accounting_uncached_input_tokens` for Fresh only) for usage
  KPIs, period filters, tool filters and rows, model/project rows, trend buckets,
  comparisons, calendar totals, Work Type, Work Step, and Work Item totals and
  shares. Period and calendar store queries return both raw and exact-fresh
  totals in one SQL read so a scope change can rebuild from loaded events
  without reloading event history. Work Type, Work Step, and Work Item grouping
  must use that same event-level projection (`total_tokens` for Include cache,
  or `output_tokens + accounting_uncached_input_tokens` for Fresh only) instead
  of a separate raw `total_tokens` sum. Workflow coverage, source-detail, and
  raw input accounting projections continue to use raw totals.
- The compact panel summary query returns both the complete raw total and the
  exact fresh total in the same store read. `TokenUsagePanelSummarySnapshot`
  projects only its headline total from `SpillSettings.tokenUsageInputScope`;
  tool, task, source, event-count, workflow, and detail rows continue to use the
  complete raw summary. Because the panel already observes `SpillSettings`, a
  scope change re-renders the headline without another store read or timer.
- The main process observes usage-input scope changes, forces a menu bar token
  refresh, and posts the existing distributed settings-change notification with
  a dedicated setting key. The running dashboard helper reloads that key from
  the shared defaults suite so its observed `SpillSettings` instance invalidates
  the overview KPI view immediately. This synchronization is notification-driven
  and must not add a polling timer, data upload, or dashboard process restart.
- A dashboard scope rebuild must not show scope-dependent KPIs, filter totals,
  model rows, trends, calendar values, Work Type, Work Step, or Work Item rows
  from different scope snapshots at the same time. Instead of redacting those
  surfaces during the rebuild, the view keeps rendering the previously applied
  snapshot's own scope (every scope-dependent value reads from that one
  snapshot, including the KPI headline) so nothing flashes a reload state; the
  view switches wholesale, in a single re-render, once the rebuilt snapshot for
  the newly selected scope lands. Workflow coverage, source-detail, and raw
  accounting rows remain cache-inclusive by design.
- Runtime importers preserve pricing-relevant token accounting separately from
  the strict usage event JSON. The strict event schema remains limited to raw
  `input_tokens`, `output_tokens`, `total_tokens`, and `token_breakdown`.
  App-owned storage may attach local-only accounting fields for uncached input,
  cache-creation input, cache-read input, unclassified input fallback, and
  reasoning output. External file adapters that cannot write SQLite directly
  may write a same-basename `.accounting` sidecar beside the `.json`/`.jsonl`
  inbox event file; the sidecar may contain only span id, safe tool label, and
  numeric accounting buckets.
- Event identity is separate from display totals. When changing a runtime
  measurement baseline, importers should preserve stable event identity where
  possible and repair numeric totals in place instead of duplicating historical
  rows. Claude Code uses `input_tokens + cache_creation_input_tokens` as its
  `span_id` input component while storing cache-read-inclusive raw
  `input_tokens`.

### ARD-005B2: Token Usage Separates Runtime Diagnostics and User Visibility

Decision:

Dashboard, panel, Preferences, and menu-bar token content use the supported
agent set (Codex, Claude Code, and Antigravity/AGY) minus the user's hidden
tools. Runtime installation is not a display gate. Current process presence is
not a display gate. Eligible usage totals still come from the app-owned
`TokenUsageStore`.

Agent-status presentation uses the canonical ordered projection Codex, Claude
Code, then Antigravity/AGY. `AIStatusStore` keeps the raw provider result
separately from the presentation list. Each refresh merges a detected status
into the matching canonical card by `LocalAIToolKind`; missing supported tools
receive a neutral presentation state without changing the order. Additional
non-dashboard statuses may follow the three canonical agent cards.

Setup, adapter diagnostics, and history-import availability consume the raw
detected-status list. They must never infer installation from the presentation
list or its neutral cards.

The Preferences AI Visible toggle list always shows the three supported agent
tools. Spill setup files, adapter hooks, importers, prior Spill installation,
and runtime discovery do not change whether a row appears. The user's show/hide
preference (`hiddenTools`) is the only normal display filter across the AI
dashboard and compact-panel AI surfaces. Runtime and adapter connection state
remain available through separate Setup and history-import UI.

Rationale:

Process presence answers "is this tool running now?" Installation answers
"can setup or history import target this runtime?" Adapter connection answers
"is Spill actually collecting for this tool?" Token usage answers "what exact
usage has been recorded?" These signals have different lifecycles. A valid
stored Codex row must remain visible even when runtime discovery misses a
user-managed installation path. The AI Visible toggle controls token display;
setup and connection state remain separately inspectable and repairable.

Rules:

- `TokenMeteringToolAvailability` owns the supported token-agent set and the
  separate installed-runtime mapping used by Setup and history import.
- Dashboard, panel, and menu-bar token content includes only
  `supportedTools - hiddenTools` in normal mode.
- The Preferences AI Visible toggle list uses `supportedLocalToolKinds`. It
  must not read or depend on runtime discovery, adapter connection diagnostics,
  shared setup-script roots, hook files, importer state, or
  `TokenMeteringSetupActionStore`.
- Dashboard agent-status cards and compact-panel AI cards use the supported
  tools minus `hiddenTools`. Menu-bar server health and history-import targets
  continue to use `installedTools` alone, so only real local runtime targets
  are inspected, reported, or repaired from those surfaces.
- Advanced dashboard mode may add stored OpenAI SDK and `unknown` history to
  the current token-display set, but it must retain `hiddenTools` for supported
  agents and must not delete any rows.
- AI process status panels may read running state from `AIStatusStore`, but
  token totals, tool tabs, panel summaries, Work Items, dashboard filters,
  history-import rows, and AI-visible toggles must never use running process
  state as eligibility.
- Store queries must use the eligible tool set. Uninstalling a runtime does not
  delete or rewrite its stored usage, labels, aliases, or cursor state.
- Manual Private Usage Upload Sync Now is an upload and freshness action for
  encrypted web backup. It must not be required for local token usage to appear
  in the native panel, menu bar, or local dashboard.
- Dashboard, panel, and menu bar refresh actions may request lightweight local
  collection or event inbox drains, but visible usage must refresh from the
  app-owned store through direct reads or store-change notifications.
- If the read-only stats helper shows usage records while native UI is empty or
  stale, investigate store drain, notification propagation, dashboard filter
  state, and user-hidden tool settings before changing importers, upload sync,
  or token schemas.
- Display mismatch diagnosis must preserve the token metering privacy boundary:
  do not inspect prompts, responses, commands, file paths, logs, transcripts,
  source content, shell history, environment values, or secrets.

### ARD-005B1: Explicit Local History Import Reconciles Known Runtime Stores

Decision:

Token metering settings must expose an explicit "Import Local History" action.
Each run attempts the selected installed first-class local runtime importers.
The normal All action resolves the current installed tool set first and does
not start importers for absent runtimes. It imports exact historical usage only
from known local runtime stores. This is a user-initiated local backfill and
reconciliation job, not automatic install behavior and not cloud sync.

Rationale:

Long-time users can have useful exact token usage records before installing
Spill metering. A one-time backfill closes that gap, while repeated explicit
imports should also recover late same-day records such as Claude Code subagent
transcripts. The job must be idempotent because users can close Preferences,
reopen settings, retry after interruption, or run the import multiple times.

Rules:

- The import job is owned by an app-wide coordinator, not by the Preferences
  view lifecycle.
- One explicit All run must attempt each currently installed supported runtime
  and report per-tool results. Per-tool rows and actions are shown only for
  installed supported runtimes. The selected scope is not limited to whichever
  runtime process is currently running.
- Importers may parse only exact numeric usage records and safe opaque metadata
  from known runtime stores.
- Repeated imports for Codex, Claude Code, and Antigravity/AGY may repair raw
  numeric totals and local-only accounting buckets for an existing stable
  `span_id`; they must preserve existing workflow labels, local grouping
  metadata, and display aliases instead of creating duplicate historical rows.
- Event identity, cursors, same-day reconciliation, checkpointing, and
  duplicate handling are specified in `specs/token-history-import.md`.
- Local history import only writes the app-owned local usage store and local
  cursor/diagnostic state. Future cloud usage sync is a separate opt-in app
  policy.

### ARD-005E: Private Usage Upload Uses Optional Runtime Configuration

Decision:

Expose the Private Usage Upload preferences surface as an optional token
monitoring action in app builds, while keeping web and relay endpoints supplied
through the existing environment and `Info.plist` configuration path.

Rules:

- Local token metering remains active without login, web connection, cloud
  upload, telemetry, or a running web app.
- The Sign In and Connect button opens only a configured safe web URL. If the
  web URL is absent or invalid, the button is disabled instead of falling back
  to a hardcoded production URL.
- Deep-link connection handling may be registered in app builds, but it stores
  only the write-only device credential returned by the configured relay.
- Private Usage Upload secrets use one Keychain generic-password item per
  environment. That item contains the device upload credential, browser
  key-wrapping secret, and local bucket sealing-key ring as a JSON bundle. The
  app may migrate older per-secret Keychain items into that bundle, then delete
  the legacy items best-effort. This keeps macOS authorization prompts to one
  connection item instead of one prompt per secret.
- Preferences, panel, and dashboard entry paths must not synchronously read that
  Keychain bundle or compute dirty upload buckets on the main actor. Connection
  state, queued-bucket counts, and migration checks must refresh through
  background tasks so opening Token Metering settings stays responsive.
- Automatic and manual uploads still require a saved connection and explicit
  `privateUsageUploadEnabled` setting.
- SQLite maintains a private-usage event-change journal through insert, effective
  update, and delete triggers. Upload state persists the last processed change
  id and pending local day ids. A schema upgrade seeds the journal once from
  existing rows so established installations can backfill without returning to
  full-history scans on later runs.
- Upload planning merges journal entries newer than the persisted cursor with
  pending day ids, selects at most one bounded batch, and loads events only for
  those local-day intervals. Ineligible current-day or pre-connection automatic
  work remains pending instead of being lost when the journal cursor advances.
- Persisted local-day ids are Gregorian `yyyy-MM-dd` values. Both formatting
  and interval parsing use a Gregorian calendar with the bucket timezone;
  `Calendar.autoupdatingCurrent` may still define local midnight boundaries but
  must not reinterpret the persisted year under a non-Gregorian user calendar.
- Daily aggregate `generated_at` is derived from the latest included event
  timestamp, not wall-clock sync time. Identical daily content therefore keeps
  stable encrypted and shared-summary hashes across retries and later runs.
- Dirty day ids are also passed to aggregate construction. When a selected day
  has no remaining events after a delete or reconciliation, the builder emits a
  deterministic zero aggregate whose `generated_at` is local day start. The
  existing bucket key is therefore replaced through the normal compatible
  upload contract instead of remaining stale remotely.
- Environment-scoped upload state stores a SHA-256 sync-target fingerprint over
  the relay device id and wrapping-key id. A first connection, changed target,
  or reconnect after disconnect clears acknowledgements and seeds pending day
  ids from all current local event dates while advancing the journal cursor to
  the checkpoint captured with that seed.
- The journal cursor and processed pending days are committed only after the
  relay acknowledges every requested bucket/summary, or when rebuilding the
  selected days proves there is no uploadable content change. Transport and
  partial-acceptance failures preserve the previous state for retry.
- Once that state save completes, the store prunes journal rows through the
  minimum committed cursor for every environment with a saved connection. The
  state save happens first so pending unprocessed days remain recoverable,
  pruning failure is harmless growth, and rows newer than the slowest connected
  environment cursor remain available for the next plan. Explicitly disconnected
  environments are excluded because their next connection forces a full resync.
- Upload status derives encrypted-bucket and shared-summary queue counts from
  one upload plan. Status refresh must not repeat the same SQLite range reads,
  aggregation, and sealing work independently for each count.
- Automatic upload and Manual Sync Now must request the local token collection
  and inbox drain path before building encrypted daily buckets. This freshness
  pass must remain local-only, use existing exact-usage importers/queue drains,
  and must not inspect prompts, transcripts, source files, shell history, or
  arbitrary logs to infer usage.
- Dirty daily buckets must aggregate the same local-only accounting buckets
  used by local cost views. The encrypted plaintext includes accounting totals
  inside each aggregate token-total object, including top-level totals and
  grouped tool, model, task, stage, workflow, and Work Item totals. Unknown or
  legacy rows without accounting are counted as unclassified input so model
  pricing can remain honest without pretending cache splits were known.
- Dirty shared summaries are a plaintext aggregate mirror for member-readable
  dashboards and fallback views. They must include the same safe Work Item
  aggregate list as the encrypted daily aggregate so dashboards do not lose
  Work Item rows when they render shared summaries instead of decrypted buckets.
  Allowed Work Item fields are limited to id, AI tool, task type, stage, model,
  token totals, first event timestamp, and last event timestamp. Shared
  summaries must reject or omit prompt text, responses, commands, file paths,
  repo names, branch names, terminal output, logs, diffs, source content,
  environment values, secrets, raw event ids, `run_id`, and `span_id`.
- Every token-total object in encrypted aggregates and shared summaries carries
  the numeric accounting totals needed for cache-aware pricing. When an
  accounted event reports fewer measured input tokens than its raw input total,
  aggregation adds the remainder to unclassified input. Relay validation may
  normalize a missing safe remainder but must never strip valid accounting
  metadata or infer a cache split.
- Automatic upload keeps the daily completed-bucket cadence. Manual Sync Now may
  include the current local day's partial aggregate so explicit user sync can
  update the web dashboard's work-item list without waiting for the next day.
  Current-day partial uploads must use the same daily bucket identity and be
  replaceable through the existing encrypted bucket upsert path.
- Missing relay configuration fails closed through the unavailable relay client.
  It must not trigger local data loss, prompt inspection, or raw event upload.

### ARD-005D: Agent-Facing Status Uses A Read-Only Local Stats Helper

Decision:

Install a small read-only stats helper beside the setup helper so agents can
answer explicit user requests such as "spill" or "Spill status" from the
app-owned local usage store.

Rationale:

The local dashboard remains the rich UI surface, but users may ask the active
agent for a quick status report while staying in the agent conversation. The
helper keeps that path deterministic and privacy-scoped without asking agents to
hand-write SQLite queries or inspect runtime logs.

Rules:

- The helper reads only the app-owned `token_usage_events` store and sanitized
  usage JSON fields needed for numeric input/output aggregates.
- The default query is self-scoped to the current runtime tool using
  `SPILL_TOKEN_USAGE_AI_TOOL`, `SPILL_AI_TOOL`, or the Codex default when no
  runtime env label is installed.
- Agent-facing instructions must include explicit commands for all first-class
  runtime labels: `--tool codex`, `--tool claude`, and `--tool antigravity`.
- The helper may output aggregate totals, event counts, model/task/stage
  breakdowns, token detail categories, and recent activity.
- The helper must not write usage events, labels, diagnostics, hooks, importer
  cursors, or setup files.
- The helper must not inspect prompts, responses, commands, file paths, repo
  names, branches, terminal output, logs, diffs, source content, environment
  values, transcripts, shell history, or secrets.
- A stats helper run is not evidence that the current turn was recorded. It is
  only a read-only report over events that already exist in the local store.
- Custom workflow labels must not encode task text, feature names, project
  names, file names, branch names, ticket ids, user names, or private content.
- The `ai_tool` label is additive and content-free. Missing labels from older
  local events decode as `unknown`; new hook-submitted events should include one
  of `codex`, `claude`, `antigravity`, `openai`, or `unknown`.
- `run_id` is an opaque grouping key only. Dashboard copy must not imply that it
  is a chat title, project name, or human-readable session name.
- Human-readable session display names require a separate local alias or
  configured safe label source. The alias must be local-only, user-controlled or
  supplied as a reusable safe slug by a trusted hook, and must never be inferred
  from prompts, commands, file paths, repo names, branch names, ticket ids,
  transcript text, logs, source content, user names, or other private content.
- Cloud sync must not be triggered by local events.
- Future account sync must keep token usage data sync and settings sync as
  separate opt-in scopes. Usage data sync may never imply syncing local aliases,
  adapter setup preferences, or dashboard display preferences.
- Settings sync must support selected-setting sync in addition to all-settings
  sync so sensitive or workflow-specific local preferences can stay local while
  usage aggregates sync.
- Global agent setup instructions must be silent and must not add metering
  status lines to normal assistant replies.
- Global agent setup instructions are not a runtime hook. They cannot expose
  token counts by themselves, and the app must not imply otherwise.
- Runtime hook input contracts differ by tool and must be handled explicitly.
  The receiver must not infer token usage merely because a hook process ran.
- Antigravity/AGY uses a local active importer as the primary collection path.
  Spill setup must remove managed AGY `PostInvocation` entries instead of
  installing hook-based metering, because real AGY turns can skip hooks, run
  hooks with empty stdin, or run hooks without exact token fields. A hook command
  log or permission prompt is therefore misleading setup evidence, not a
  reliable metering path.
- Antigravity/AGY exact token counts may arrive through the active importer
  only. The importer may read known AGY conversation metadata records
  read-only, but must store only safe shape booleans plus usage numbers, never
  raw environment values or content-like fields.
- AGY metadata field numbers used by the active importer are observed local
  implementation details, not an AGY public protobuf contract. If AGY changes
  those shapes, the importer must skip unsupported records or wait for an
  explicit parser update; it must not infer token counts or labels from
  content.
- Claude Code Stop hooks use a separate contract. The expected stdin payload is
  a safe object with `transcript_path`; the adapter may read exact numeric usage
  from that transcript but must not store transcript paths or transcript
  content. Empty stdin, no assistant usage, zero tokens, or no new token delta
  go to `claude-last-empty.json`; invalid payloads, missing transcripts, or read
  failures go to `claude-last-mismatch.json`; successful enqueue goes to
  `claude-last-success.json`.
- Diagnostic files are local-only support state. They may contain fixed
  booleans about payload shape, safe labels, model id, numeric token counts, and
  timestamps, but never raw payload values, prompts, responses, commands, file
  paths, transcript paths, transcript content, repo names, diffs, logs, source
  content, environment values, secrets, run ids, or span ids.
- A one-step setup helper may install bundled adapter scripts and merge known
  user-level hook files for detected tools, but it must be explicit opt-in,
  support dry-run behavior, avoid overwriting unrelated hook entries, and back
  up existing config files before writing.
- Preferences and the local token dashboard may run the bundled setup helper
  directly after an explicit `Install`, `Reinstall`, or `Repair` button click.
  The app must first install or refresh its bundled helper resources, execute
  the helper with `--apply --metering-only`, keep the UI responsive, and expose
  a safe success or actionable failure state. Metering-only mode installs exact
  collection adapters and runtime settings but does not add the shared runtime
  instruction or runtime instruction bridges. It must preserve existing bridges
  and workflow integrations and must not run setup automatically on view
  appearance, dashboard refresh, app launch, or instruction copy.
- The setup action label is derived from app-owned setup installation state.
  Setup presence and helper exit success are configuration evidence only; they
  are not evidence that a real Codex, Claude, or Antigravity/AGY turn recorded
  exact tokens.
- The default public setup helper mode must install the canonical agent
  instruction at `~/.spill/runtime-instruction.md` with owner-only permissions.
  Runtime-specific
  user instruction files are discovery bridges only and must not contain a full
  duplicated Spill instruction.
- The Codex bridge targets `~/.codex/AGENTS.override.md` when that file already
  exists, otherwise `~/.codex/AGENTS.md`. The Claude Code bridge imports the
  canonical file from `~/.claude/CLAUDE.md`. The Antigravity/AGY bridge points
  to the canonical file from `~/.antigravity/AGENTS.md`.
- Instruction bridge writes must be idempotent, preserve unrelated user text,
  keep one managed Spill block per target, and back up a changed existing file.
- Setup helper output, setup UI, and copied agent-facing install prompts must
  disclose that known local JSONL, transcript, or metadata stores can be read
  locally only for exact token metadata, and must repeat that content-like
  fields are not stored or uploaded.
- A user request to install, apply, fix, or verify Spill token metering counts
  as opt-in for the one-step helper to install all detected supported adapters
  and merge known user-level hook configs in one pass. The agent-facing prompt
  must not make users copy or install Codex, Claude, Antigravity/AGY, and
  OpenAI adapters separately.
- Workflow hook installation is a separate user-selected action. The helper may
  write a selected `.agents/hooks.json` or equivalent workflow hook file only
  when the path is passed explicitly by the user or a trusted workflow setup.
- Preferences and the local dashboard must expose workflow-aware setup as a
  copied instruction separate from basic installation. That instruction treats
  the current directory as the workflow root, asks the user to relocate when it
  is not the owning directory, inspects only that root for trusted workflow
  entry points, and must not scan unrelated directories for possible workflows.
- Existing workflow scripts that expose safe reusable labels should pass those
  labels to adapters through exact hook payload fields, flags, or environment
  variables. Adapters must not read prompts, commands, logs, diffs, source, or
  transcript text to recreate the workflow stage.
- Static hooks that cannot receive dynamic payload fields or environment
  variables may read a short-lived label context file written by an agent or
  trusted workflow. That file may contain only `ai_tool`, `task_type`, `stage`,
  `updated_at`, and `expires_at`; adapters must ignore expired,
  tool-mismatched, or unsafe slugs.
- Supported detailed labels should include common implementation and agent
  workflow categories such as `code_review`, `review_response`, `git_commit`,
  `commit_message`, `pull_request`, `workflow_setup`, `build_verification`,
  and user-defined safe reusable slugs.
- Prompt-driven agents must never inspect local logs, transcripts, shell
  history, repository files, or hidden state to reconstruct token usage.
- A user-installed local importer is a separate runtime adapter, not an agent
  prompt behavior. Importers may read only known exact token-usage records and
  safe runtime metadata from supported local tool stores. If the only available
  exact usage record lives in a local transcript-like file, an adapter may parse
  only the numeric usage object and safe opaque runtime metadata from that file;
  it must not inspect content, commands, paths, diffs, logs, or source text, and
  must not infer `task_type`, `stage`, or display names from transcript steps or
  message text. For Codex, the importer runs on demand from a trusted hook or
  workflow, reads recent `~/.codex/sessions/**/rollout-*.jsonl` files, and
  parses only `event_msg/token_count` usage records plus safe opaque
  session/model metadata. It must enqueue one event file per imported span and
  must not parse or store prompts, assistant responses, commands, file paths,
  working directories, diffs, terminal output, source content, environment
  values, or secrets.
- Codex importer spans are deduplicated with opaque hashes and stored as
  `ai_tool = codex`, `artifact_id = artifact_codex`, and `project_id =
  project_global` local events. Spill settings decide whether and how local
  aggregates sync later.
- Antigravity/AGY importer spans are deduplicated with opaque hashes and stored
  as `ai_tool = antigravity`, `artifact_id = artifact_global`, and
  `project_id = project_global` local events. The importer scans recent AGY
  conversation metadata records read-only and extracts only exact numeric usage
  fields, safe model ids, and opaque conversation or generation ids. It must not
  store prompts, responses, commands, file paths, conversation titles, work item
  titles, logs, diffs, source content, environment values, secrets, raw database
  paths, or arbitrary transcript content. It writes local-only aggregate
  diagnostics such as `antigravity-active-importer-last.json` so support can
  distinguish "no source", "no exact fields", and "events imported" without
  storing private payload values.
- Local token metering data has not shipped as a compatibility-boundary product
  feature. During development, existing experimental token rows, diagnostics,
  importer cursors, and adapter caches may be reset, rebuilt, or reimported
  when the schema or runtime source changes. This does not loosen the privacy
  boundary: adapters still must not inspect content-like fields or estimate
  usage.
- The local app always reads the app-owned local store. UI must not imply that
  metering starts only after pressing a local check button.
- The dashboard may filter Work Items by opaque `project_id` values so local
  work can be grouped without exposing paths or names. `project_global` is the
  unassigned bucket. Display labels must be derived from short opaque ids only.
- Dashboard filters must be deterministic navigation controls. Period, tool,
  and folder filters apply before charts and Work Items are built; folder
  filters sort by their safe display labels, not token volume.
- A local dashboard self-test may enqueue one synthetic `local_only` event
  through the local queue. The event must be clearly identifiable as self-test
  data with opaque ids, safe enum labels, and numeric buckets only. It must be
  treated as optional diagnostics and must not read prompt text, commands, file
  paths, logs, source, environment values, or secrets.

### ARD-005F: Spill Glance Uses A Main-Process Nonactivating Panel

Decision:

The always-visible Spill Glance surface is a main-process feature boundary under
`Sources/Spill/Glance`. It uses a lightweight feature store for presentation
state, SwiftUI for one grouped horizontal composition with All and Ticker
styles, and an AppKit controller for `NSPanel` lifecycle, screen placement, and
full-screen Space policy.

Window contract:

- Use a borderless nonactivating `NSPanel`.
- The panel cannot become key or main, does not activate Spill, does not appear
  in the window cycle, and remains visible when another application is active.
- Use public collection behaviors to join normal Spaces. Do not participate as
  a full-screen auxiliary window by default; add that behavior only when the
  user enables the native full-screen visibility preference.
- On first launch, center the panel horizontally inside the chosen
  `NSScreen.visibleFrame` and place it 10 points below that frame's top edge.
  Do not overlap the menu bar, notch, or status items.
- Keep one panel instance across all connected displays. During a drag, choose
  the `NSScreen` whose frame contains the absolute pointer and constrain the
  panel to that screen's `visibleFrame`; never create one panel per display.
- Use a clear window background. SwiftUI owns one rounded material capsule with
  internal module separators and a single material/glass layer; there is no
  full-row opaque AppKit card, stacked tint material, or set of separately
  floating capsules.
- A SwiftUI drag gesture distinguishes a click from a drag and forwards the
  initial translation to the controller. The controller reconstructs the
  mouse-down point once, then follows the absolute public
  `NSEvent.mouseLocation` screen coordinate so moving the window cannot feed
  back into the gesture coordinate space.
- Live drag updates move only the composited panel origin with
  `setFrameOrigin`. They do not force unchanged transparent SwiftUI glass
  content to display for every pointer event. The controller clamps the result
  to the pointer-selected `visibleFrame` and saves the final frame through
  `SpillGlanceFrameStore`.
- `SpillGlanceFrameStore` persists display identity and a placement descriptor
  relative to `NSScreen.visibleFrame`. Near-edge X/Y axes store leading,
  trailing, top, or bottom anchors with fixed insets; free axes store normalized
  ratios. This preserves corner intent such as right-bottom across resolution,
  menu-bar, Dock, and work-area changes instead of replaying stale absolute
  coordinates.
- On restoration, the frame store resolves the preferred connected display and
  applies the saved semantic placement to the current content size. If the saved
  display is unavailable, the controller applies the same placement to the
  primary-display fallback without overwriting the preferred display identity.
  A later screen-parameter notification can therefore restore the external
  display after reconnection. A legacy absolute frame migrates only when its
  containing display is available.
- Horizontal layout uses the saved semantic X/Y placement and remains draggable
  across the full visible frame and connected displays. Top, bottom, and corner
  anchors therefore survive display geometry changes without a separate
  orientation or wall-side preference.
- Hide the panel when Glance is disabled or no module is enabled.

Data and action flow:

```text
TokenUsageStore events ------------------------------\
calendar-day / system-clock / timezone notifications -> TokenUsageDashboardStore
                                                              |            |
                                                              |            +-> panelSummary
                                                              |                (dashboard hidden-tool filtered)
                                                              |
                                                              +-> glanceSummary
                                                                  (unfiltered current day,
                                                                   all supported tools)
                                                                          |
SpillSettings Glance preferences -----------------------------------------+-> SpillGlanceStore.state
                                                                                  |
                                                                                  v
                                                                       SwiftUI All/Ticker row
                                                                             /          \
                                                                            v            v
                                                        existing dashboard action   Glance Preferences
```

The store projects presentation-ready values and observes the existing
publishers. `TokenUsageDashboardStore.panelSummary` keeps its existing
dashboard hidden-tool filter. Its `glanceSummary` companion instead covers the
current local calendar day across all supported tools, regardless of dashboard
visibility, so hiding a dashboard agent never removes that agent from an
explicitly enabled Glance segment or from All Today.

The dashboard store rebuilds both summary companions when token usage store
events arrive. It also observes macOS calendar-day, system-clock, and timezone
change notifications and refreshes both companions so current-day boundaries
remain correct without waiting for another token event. This adds no polling
loop, database watcher, process probe, collector, network request, cloud service
status request, or upload path.

The separate dashboard helper disables the Glance companion load because it
does not render Glance. It still consumes the same event-driven calendar
invalidation for its own Today snapshot, so this optimization does not make an
open helper stale or add a second lifecycle.

`AppDelegate` remains the composition root and injects the same dashboard
store, settings instance, dashboard-opening closure, and Preferences navigation
closure already used by the compact panel and menu bar.

Settings and propagation:

- `SpillSettings` remains the persistence owner.
- `SpillGlanceFrameStore` owns only local display identity and semantic window
  placement. It does not become a user-visible setting or sync payload.
- New installations default the surface to enabled with only All Today, Work
  Type, and settings visible. Codex, Claude, and Antigravity are opt-in
  segments. All Today and Work Type remain fixed while the surface is enabled.
  `glanceWorkRotationEnabled` defaults to `true` when its persisted key is
  absent, preserving the existing rolling presentation for upgrades.
  `glanceDisplayStyle` defaults to All when its persisted string is absent or
  invalid, `glanceShowInFullScreen` defaults to `false`, and
  `glanceReactiveRotationEnabled` defaults to `true`. The unreleased
  orientation and wall-side keys have no readers after vertical mode removal.
- Preferences and Glance live in the main process, so `@Published` delivery is
  the explicit real-time propagation path. Changing Work rotation rebuilds the
  Glance presentation without restart, reopen, manual refresh, polling, or
  helper-process invalidation. Display style and native full-screen visibility
  use the same path. Because `@Published` emits during `willSet`, the
  AppKit bridge schedules presentation consumption on the next main-queue turn
  and reads the store's committed value. This keeps the visible update within
  one display frame instead of waiting for the five-second `TimelineView`
  cadence.
- The AppKit bridge tracks an explicit layout signature containing the ordered
  modules and display style separately from content values. It
  reapplies placement and content size only when that signature changes; a token
  value or Work rotation update redraws content without moving, resizing, or
  reordering the panel.
- The dashboard helper, compact panel, clock-adjacent AI glance, web dashboard,
  Private Usage Upload, sync payloads, and agent-facing summaries do not read
  these presentation settings. No distributed notification or sync migration is
  added for them.
- Legacy AI Status, Top Task, and Today Tokens ids migrate to all three optional
  tool segments. Unknown and duplicate ids normalize deterministically. An
  empty optional-tool set is valid; fixed segments remain until the master
  surface switch is disabled.

Work Type rotation:

- `TokenUsageDashboardStore.glanceSummary.taskRows` arrives in descending usage
  order for the current local day across all supported tools. Glance projects
  those labels into compact display values paired with each row's compact
  formatted token total. The dashboard's hidden-tool-filtered `panelSummary`
  remains independent and unchanged.
- `glanceWorkRotationEnabled` decides whether Work may change value at all;
  `glanceReactiveRotationEnabled` decides what drives every rotation.
- Reactive rotation (default): `SpillGlanceStore` diffs consecutive
  `glanceSummary` projections against a per-module and per-work-row baseline and
  enqueues only what moved into `SpillGlanceChangeQueue`. Each change owns a
  fixed dwell, and a module that changes again inside its own dwell updates that
  entry in place instead of appending another, which bounds the queue to one
  pending slot per module and throttles bursts. Ticker style renders the active
  entry and rests on All Today when the queue is quiet; All style applies the
  queue only to the Work slot and rests on the highest-usage row. Work changes
  are diffed per task row, so a lower-usage category that just moved can take
  the slot without reordering the queue. Surface reconfiguration — module set,
  display style, or either rotation preference — clears the queue so that
  configuration-induced value differences are never replayed as usage.
- Rolling rotation (`glanceReactiveRotationEnabled == false`): `TimelineView`
  advances the display-only Work value every five seconds in All style. Ticker
  style assigns one ordered global slot to All Today, each enabled AI tool, and
  Work. The Work slot advances to its next selected value once per completed
  global queue cycle, so several Work values never outweigh the other modules.
- When Work rotation is false, the store projects only the first already-sorted
  Work row and never enqueues a Work change, so the highest-usage Work Type and
  token total remain fixed in either style and either rotation model.
- `SpillGlancePresentation.rotationSchedule` owns the schedule choice, and
  `SpillGlanceRotationTimelineSchedule` adapts it to a single `TimelineView`:
  periodic for rolling rotation, and the queue's explicit change boundaries for
  reactive rotation, so the surface stops redrawing once the queue drains.
- The preference is presentation-only and does not refresh storage, collectors,
  processes, the network, the dashboard helper, the compact panel, the
  clock-adjacent AI glance, web dashboards, upload payloads, sync payloads, or
  agent-facing summaries.
- Known long task categories use semantic short labels. Long custom safe slugs
  use bounded initials so the compact surface never depends on an ellipsis.
- Both display styles use fixed token/value typography. The SwiftUI view does
  not use minimum-scale font reduction; bounded formatters and stable All/Ticker
  width budgets own fit instead. `SpillGlanceLayout` sizes each module for its
  icon, two internal gaps, label, representative maximum compact value,
  horizontal padding, and a small rendering margin so fixed-size text cannot
  cross a separator.

Ticker and full-screen policy:

- All style shows every selected module at once. Ticker style renders one
  fixed-width slot plus the persistent settings action, so changing the active
  item never resizes or repositions the panel.
- All style gives optional tools short visible labels, fixed-width breathing
  room, established color cues, and stronger separators while preserving one
  continuous glass group and fixed typography.
- Ticker transition identity includes the module and active display value.
  SwiftUI applies one bottom-to-top slide/fade transition on the shared
  cadence — five seconds while rolling, one dwell per queued change while
  reactive — producing an electronic-sign rhythm without a data poll or a
  second timer.
- The controller applies `.fullScreenAuxiliary` only when
  `glanceShowInFullScreen` is true. A committed preference change orders the
  panel out, updates its collection behavior, then restores visibility so the
  Space assignment updates immediately while preserving placement.

Rationale:

This preserves Spill's glance-first product direction without expanding the
menu bar status-item footprint or duplicating expensive collection work.
Keeping window lifecycle behind a controller follows the lightweight feature
store boundary while using only public AppKit and SwiftUI APIs.

### ARD-006: Permission Boundaries

Decision:

Permission-dependent features must degrade cleanly.

Permissions:

- Accessibility:
  - AX menu bar scanning
  - AXPress
  - active window movement
- Screen Recording:
  - not required for MVP
  - only if future visual preview/capture features are added

Rules:

- Never request permissions before the user reaches a feature that needs them unless first-run onboarding explicitly explains why.
- Preferences must show permission diagnostics.
- Preferences should not expose menu bar scanning as a primary settings surface
  unless it becomes a clear user-facing workflow. Scanner cadence, icon scope,
  and detected-item diagnostics remain internal or contextual controls.
- UI should show disabled/fallback states, not crashes.

### ARD-006A: Web Portal Roles And Admin Authorization

Decision:

The web portal uses two product roles for the first account-backed release:

- `admin`: an administrator who is also a normal user.
- `user`: a normal end user.

Role-aware navigation and route guards are presentation behavior only. The
trusted authorization boundary is Supabase RLS and the `private-usage-relay`
Edge Function, which must derive the actor from a verified Supabase Auth session
or a write-only Spill device credential. The browser must never be trusted for
role, account id, user id, device ownership, or admin status.

Rationale:

Admin users need operational menus that normal users should not see, but hiding
a menu does not protect data. The same role model must therefore be represented
in product UI, database policy, and relay authorization so direct URL access,
browser dev tools, stale role cache, and crafted requests fail at the trusted
boundary.

Data model requirements:

- Store account membership and role in an account-scoped table such as
  `account_memberships` or an equivalent profile/role table.
- Role values are limited to `admin` and `user` for MVP.
- A user may be an admin for one account and a normal user for another future
  account only if account scoping is explicit in every role lookup.
- The first admin is created by an explicit bootstrap path, not by client-side
  self-assignment.
- Role changes require a privileged trusted path and must not be possible
  through direct browser table writes.

Authorization rules:

- UI may hide admin navigation until role state confirms `admin`.
- UI hiding is not authorization; all protected reads and mutations must be
  blocked by RLS or an Edge Function permission check.
- Role checks in the relay must query the server-side role table using the
  verified actor id and account scope.
- Write-only device credentials cannot read account data, read encrypted
  buckets, create device grants, manage devices, or call admin routes.
- Admin mutations must be action-scoped. Prefer checks such as
  `can(actor, "admin.user_role.update", { accountId })` over scattered
  role-name conditionals.
- Admin errors must be redacted and should not reveal private resource
  existence beyond product policy.

Audit requirements:

- Role changes, user administration, device revocation, private upload setting
  changes, and future privileged support actions must write an admin audit row.
- Audit rows may include actor id, account id, action, target id, result,
  reason code, request id, and timestamp.
- Audit rows must not include prompts, responses, commands, file paths, logs,
  diffs, source content, environment values, secrets, raw token events, bucket
  plaintext, local aliases, or service-role values.

Implementation order:

1. Add role/account membership schema and helper functions such as
   `is_account_admin(account_id, user_id)`.
2. Add RLS policies for normal self/account data and admin-only tables/actions.
3. Add relay permission helpers that verify Supabase JWTs and re-check roles
   server-side before admin responses or mutations.
4. Add web viewer state that loads the role from a safe DTO and hides admin
   menus while loading.
5. Add route guards that block direct admin routes for non-admins.
6. Add content-free admin audit logging for privileged mutations.
7. Add tests for unauthenticated, normal user, admin, stale role, direct route,
   direct API call, device credential, and revoked role cases.

### ARD-006B: Hosted Web Source Boundary

Decision:

The open-source macOS app and shared token-only contracts remain public. The
hosted Spill web portal implementation lives in the private
`taehwandev/Spill-web` repository so hosted UI implementation, deployment
wiring, and product experiments stay out of the public source tree.

Browser-delivered JavaScript and HTML are never a trusted secret boundary. Route
guards and hidden navigation are presentation controls only; every protected
read, mutation, admin response, device action, and account-scoped query must
still be enforced by Supabase RLS or the `private-usage-relay` Edge Function.

Rationale:

Open-source users should be able to inspect and run the Mac app and local
token-metering safety contract. Hosted account surfaces have different product
and abuse considerations. Separating hosted web source can reduce public
implementation exposure, but it does not replace server-side session, role, and
account authorization.

Rules:

- Keep public env templates value-free and never commit hosted secrets.
- Do not rely on minification, route hiding, bundle splitting, or feature flags
  as authorization.
- Public web code may include self-hostable examples only when they do not
  expose hosted deployment internals or privileged behavior.
- Keep shared schemas, DTO contracts, and privacy guarantees documented in the
  public app repo when they affect the open-source app or local metering safety
  contract.
- Protected routes must render only after a signed-in viewer is available.
- Admin routes must render only after the server-provided viewer role confirms
  `admin`.

### ARD-007: Distribution Model

Decision:

Target Developer ID signed and notarized distribution outside the Mac App Store.

Rationale:

The app requires Accessibility and low-level utility behavior. Mac App Store review and sandbox constraints may limit the product. Direct distribution is more realistic.

Distribution requirements:

- Hardened runtime.
- Developer ID Application certificate.
- Notarization with `notarytool`.
- Stapled ticket.
- DMG or zip release artifact.
- GitHub Releases.
- Sparkle appcast for in-app updates.
- Optional Homebrew Cask.

### ARD-008: Lightweight Feature Store Architecture

Decision:

Use a lightweight unidirectional feature-store architecture for UI-facing app
behavior. SwiftUI views render state and send actions. Feature stores own
state transitions, presentation-ready derivation, and feature-level async
effects. System-specific behavior remains behind adapters, clients, providers,
or AppKit bridge controllers.

The target shape is:

```text
SwiftUI View
  -> FeatureStore.send(Action)
  -> FeatureStore updates State
  -> FeatureStore calls Provider / Service / Adapter
  -> Adapter talks to public macOS APIs
```

Rationale:

Spill has several external event sources: the menu bar trigger, global
shortcuts, Accessibility permission state, AX scanning, status polling, window
movement, power assertions, and app/window lifecycle notifications. Plain MVVM
would likely push too much system coordination into view models. A full Redux,
TCA, or global reducer architecture would add more ceremony than the app needs.

This project should keep the React-style benefits that matter:

- UI is a pure function of observable state where practical.
- User and system events enter through explicit actions.
- Async work is launched and cancelled by the owning feature store or
  coordinator.
- AppKit and Accessibility details do not leak into SwiftUI views.

This project should avoid:

- a single global `AppState`;
- a single global `Action` enum;
- reducer framework dependencies unless the app grows enough to justify them;
- putting `NSPanel`, `NSStatusItem`, `AXUIElement`, `IOPMAssertionID`, or
  `NSWorkspace` details directly in SwiftUI views.

Naming rules:

- `FeatureState`: plain value model for rendering and availability state.
- `FeatureAction`: user or system event accepted by the feature.
- `FeatureStore`: `@MainActor ObservableObject` that owns published state and
  handles actions.
- `Provider`: reads or transforms domain/system information into plain models.
- `Adapter` or `Client`: wraps public macOS APIs and side effects.
- `Controller`: reserved for AppKit object lifecycle, delegates, or system
  APIs that require reference semantics.
- `Coordinator`: reserved for wiring timers, notifications, shortcuts, or
  cross-feature event streams.

Implementation rules:

- `AppDelegate` should become the composition root and lifecycle entry point,
  not the owner of feature orchestration.
- SwiftUI views should avoid deriving feature state directly from multiple
  stores, scanners, settings, or providers. That derivation belongs in a
  feature store or presentation model.
- Stores may depend on providers and adapters, but providers must not depend on
  SwiftUI or AppKit view types.
- Providers and planners should return plain `Sendable` models where possible.
- AppKit bridge controllers may keep owning `NSPanel`, `NSStatusItem`, and
  window delegate behavior, but should receive feature stores, state, or
  closures instead of embedding business rules.
- AppKit window controllers must stop window-scoped work when a window closes.
  `PreferencesWindowController` releases its hosted SwiftUI content and
  window-scoped observations on close, then recreates them on the next show so
  preview animations cannot retain a hidden view tree.
- Permission-required, unavailable, disabled, success, and failure states must
  be represented explicitly in feature state or action results.

Migration order:

1. Introduce `PanelState`, `PanelAction`, and `PanelStore`. Move panel display
   derivation out of `SpillBarView`.
2. Slim `AppDelegate` into app startup, environment construction, and lifecycle
   forwarding.
3. Keep `SpillPanelController` and `StatusItemController` as AppKit bridge
   controllers, but move feature policy out of them.
4. Wrap Accessibility, focused-window movement, status item hosting, panel
   hosting, workspace reads, and power assertions behind adapters or clients.
5. Consolidate status and action provider registration so new providers can be
   added without special-casing panel composition.
6. Add focused store tests for state transitions and keep pure planner/provider
   tests for system-independent logic.

## Module Boundaries

### Source Layout

Swift source files are grouped by responsibility under `Sources/Spill`:

```text
Sources/Spill/
├─ Accessibility/
├─ App/
├─ MenuBar/
├─ Panel/
├─ Providers/
├─ Preferences/
└─ Settings/
```

Keep future source files inside the closest responsibility folder. Create a new folder only when a feature has a durable ownership boundary that does not fit the existing layout.

### App Shell

Owns:

- `AppDelegate`
- preferences window
- app lifecycle

Must not own:

- provider business logic
- AX scanning details
- system metric collection details

### Menu Bar

Owns:

- status item trigger
- best-effort menu bar scanner
- menu bar item snapshots
- notch geometry

Must not own:

- panel visual composition
- preferences UI
- provider business logic

### Panel UI

Owns:

- layout
- visual style
- section composition
- click affordances

Must not own:

- metric polling
- AX implementation
- window management implementation

### Providers

Own:

- collecting state
- converting state into compact display models
- failure/unavailable messages
- provider model and protocol contracts

Provider output should be plain models that SwiftUI can render.

### Action Execution

Owns:

- AXPress
- app activation/open fallback
- window action execution

Must return explicit results:

- success
- unavailable
- permissionRequired
- unsupported
- failed(message)

## Proposed Data Models

```swift
struct SpillStatusItem: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let symbolName: String?
    let state: SpillStatusState
}

enum SpillStatusState: Hashable {
    case normal
    case active
    case warning
    case unavailable
}

struct SpillAction: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let symbolName: String?
    let iconData: Data?
    let kind: SpillActionKind
}

enum SpillActionKind: Hashable {
    case menuBarItem(stableKey: String)
    case app(bundleIdentifier: String)
    case window(WindowActionKind)
    case command(String)
}
```

## Implementation Notes

### System Metrics

Likely APIs:

- Memory: `host_statistics64`
- CPU: `host_processor_info` or sampled process/system counters, presented by
  default as a multicore/system-wide value
- Battery: `IOPSCopyPowerSourcesInfo`
- Network: `NWPathMonitor` plus optional byte counters later

Keep sampling cheap and cache snapshots.
Do not expose user-facing CPU calculation mode selection until a future PRD
defines why users need to choose a different mode.

### AI Status

MVP detection:

- Codex:
  - process detection
  - optional local config/session files if stable
- Claude:
  - process detection
  - version and model hints only when exposed by safe local command output or
    process arguments
- Gemini:
  - process detection
  - version and model hints only when exposed by safe local command output or
    process arguments
- Ollama:
  - process detection
  - `ollama ps` for currently loaded model hints when local command probing is enabled
  - optional `ollama list` only when user enables broader command probing
- OpenAI:
  - environment/config presence only
  - optional default model from explicit OpenAI model environment keys
  - never display secret values

The compact panel and dashboard render the supported agent cards in canonical
Codex, Claude Code, and Antigravity/AGY order, minus the user's hidden tools.
The sparse provider result remains the source for actual installation and
process detection, while `AIStatusStore` projects that state onto the stable
presentation list. A missing runtime therefore keeps a neutral display card but
does not become installed for Setup or history import.

Model and version labels are best-effort metadata. Spill should not inspect chat
transcripts, private session stores, or secret-bearing config files to infer an
AI session's exact model.

No external network calls by default.

### Window Actions

Use Accessibility to get focused app/window and set `AXPosition`/`AXSize`.

Store previous frame per window identifier when possible. If a stable ID is unavailable, store the most recent active-window frame as best-effort.

### Menu Bar Actions

Use stored AX element when fresh. If stale:

1. rescan;
2. find stable key;
3. retry press;
4. fallback to activating owner app.

## Key Risks

- AX visibility is incomplete.
- Some menu bar extras do not support `AXPress`.
- Window movement can fail for special windows.
- AI tool state may be hard to infer consistently.
- Direct distribution needs signing/notarization setup.

## Risk Mitigations

- Show best-effort labels.
- Provide fallback actions.
- Keep permissions transparent.
- Avoid overpromising in README and UI.
- Write provider tests around model transformation where possible.
- Prefer manual verification scripts for macOS integration behavior.
