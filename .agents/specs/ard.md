# Spill ARD

Architecture Requirements and Decisions.

## Architectural Goal

Build a compact, native macOS utility that is reliable enough to distribute and extensible enough to add system, AI, app, and window providers.

The architecture must avoid fragile menu bar manipulation and instead treat the Spill Panel as the primary product surface.

## Major Decisions

### ARD-001: No Spacer Architecture

Decision:

Use a single fixed-width status item as the visible trigger. Do not create giant or invisible spacer status items.

Rationale:

Modern macOS can hide or clip status items when space is constrained. Apple documents that status items are not guaranteed to be available at all times. Spacer behavior is therefore not a stable product foundation.

Implications:

- Spill cannot promise to physically move hidden items out from behind the notch.
- Spill must provide value through its panel and providers.

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

### ARD-005A: Token Metering Lives Inside The AI Strip

Decision:

Token metering appears as a compact summary inside the existing AI strip of the
Spill Panel. The visible menu bar trigger continues to toggle the panel. A
separate native Local Token Dashboard may exist as a detail action from that
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
- Detail actions must not start cloud sync, auth, network upload, or content
  collection.

### ARD-005C: Local Token Dashboard Uses A Separate Helper App

Decision:

The detailed Local Token Dashboard launches as a separate bundled helper app
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
- Detailed task/source breakdowns require exact runtime usage metadata supplied
  through the safe local event contract.
- `task_type` and `stage` are extensible safe workflow slugs, not closed enums.
  Spill publishes recommended labels, but AI runtimes, workflow hooks, and
  adapters may define custom reusable categories that match
  `^[a-z][a-z0-9_]{1,40}$`.

### ARD-005D: Agent-Facing Status Uses A Read-Only Local Stats Helper

Decision:

Install a small read-only stats helper beside the setup helper so agents can
answer explicit user requests such as "Spill status" from the app-owned local
usage store.

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
- The helper may output aggregate totals, event counts, model/task/stage
  breakdowns, source buckets, and recent activity.
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
  separate opt-in scopes. Usage data sync may never imply syncing local prompt
  preferences, local aliases, adapter setup preferences, or dashboard display
  preferences.
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
- A user request to install, apply, fix, or verify Spill token metering counts
  as opt-in for the one-step helper to install all detected supported adapters
  and merge known user-level hook configs in one pass. The agent-facing prompt
  must not make users copy or install Codex, Claude, Antigravity/AGY, and
  OpenAI adapters separately.
- Workflow hook installation is a separate user-selected action. The helper may
  write a selected `.agents/hooks.json` or equivalent workflow hook file only
  when the path is passed explicitly by the user or a trusted workflow setup.
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
- A local dashboard self-test may enqueue one synthetic `local_only` event
  through the local queue. The event must be clearly identifiable as self-test
  data with opaque ids, safe enum labels, and numeric buckets only. It must be
  treated as optional diagnostics and must not read prompt text, commands, file
  paths, logs, source, environment values, or secrets.

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
- CPU: `host_processor_info` or sampled process/system counters
- Battery: `IOPSCopyPowerSourcesInfo`
- Network: `NWPathMonitor` plus optional byte counters later

Keep sampling cheap and cache snapshots.

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

The panel should render only detected or configured AI tools. Missing local tools
should be omitted from the compact strip, and the whole AI strip should be hidden
when every local AI signal is absent.

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
