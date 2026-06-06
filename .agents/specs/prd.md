# Spill PRD

## Summary

Spill is a compact macOS control tray for people whose menu bar is crowded, especially on notched MacBooks.

It does not try to force macOS to reveal or rearrange every hidden menu bar icon. Instead, Spill provides a small, fast panel that combines:

- pinned menu bar/app actions;
- system status;
- AI/tooling status;
- quick window actions.

The product should feel closer to a tiny native utility tray than a dashboard.

## Problem

macOS menu bar space is limited. On notched MacBooks, menu bar extras can disappear behind the notch or be hidden by the system. Apple does not provide a public API to enumerate, clone, reorder, resize, or reveal every third-party menu bar extra.

Users still need quick access to two kinds of information:

- actionable icons that mostly serve as shortcuts;
- status indicators such as memory, CPU, battery, network, AI agent state, or unread/work state.

Existing solutions often rely on fragile spacer tricks, private APIs, large dashboards, or separate apps for each small utility.

## Product Positioning

Spill is:

- a small Mac control tray;
- a menu bar action shelf;
- a glanceable system and AI status strip;
- a light window-action launcher.

Spill is not:

- a full iStat Menus clone;
- a full Rectangle clone;
- a full Raycast clone;
- a guaranteed menu bar icon restoration tool;
- a private API menu bar hack.

## Target Users

- MacBook users with a notch.
- Developers and AI-heavy users.
- Users with crowded menu bars.
- Users who run tools like Rectangle, iStat Menus, Hidden Bar, Ice, Raycast, Hammerspoon, Ollama, Codex, or local agents.
- Users who prefer a small native utility over a large always-open dashboard.

## Core Principles

1. **Always visible trigger**
   Spill keeps one small menu bar trigger. No giant spacer.

2. **Glance first**
   The panel should answer "what is happening?" in one second.

3. **Actionable by default**
   Items should be clickable, not decorative.

4. **Best-effort is honest**
   If a third-party menu bar action cannot be pressed, show a fallback.

5. **Small surface area**
   The panel is compact. Deep configuration belongs in Preferences.

6. **Open-source distributable**
   Avoid private APIs and fragile system hooks.

## MVP Scope

### 1. Single Menu Bar Trigger

Requirements:

- A single fixed-width `...` or Spill icon appears in the menu bar.
- Left click toggles Spill Panel.
- Right click or Control-click opens a native menu with:
  - Show/Hide Spill Panel
  - Open Local Token Dashboard
  - Refresh
  - Preferences
  - Quit
- No spacer-based layout manipulation.

Acceptance:

- The trigger remains small.
- Local token usage appears inside the panel AI section.
- No invisible or oversized status items are created.
- The app remains usable when the menu bar is crowded, subject to macOS status item limitations.

### 2. Compact Spill Panel

Requirements:

- Native `NSPanel`, non-activating where appropriate.
- Appears under the notch when notch geometry is available, otherwise under/near trigger.
- Glass tray style.
- Height target: 120-180px for MVP.
- Sections:
  - Status Strip
  - AI Strip
- Token Metering summary inside the AI Strip
- Pinned Actions
- Detected Items, if useful

Acceptance:

- Panel opens within 1 second.
- Text and icons do not overlap.
- Panel does not feel like a full dashboard.

### 2A. Local Token Metering

Requirements:

- The native app reads safe token usage events from an app-owned local store.
- The default receiver is a local event queue directory, not a required
  background server.
- Hooks and adapters write one event per file using `.tmp` then atomic rename
  to `.json`; Spill imports complete `.json` files into the app-owned store.
- Local receivers are global to the computer, not tied to a repository checkout.
- Usage events use opaque ids such as `project_global` and never
  store project names, file paths, prompts, commands, terminal output, logs,
  diffs, source content, environment values, or secrets.
- `run_id` is an opaque grouping key for a local run or turn. It is not a
  human-readable session name.
- `span_id` represents one recorded usage event, such as one final assistant
  turn or one exact adapter span. A single chat conversation can contain many
  spans and multiple work categories, so the dashboard must not treat a chat
  title or raw run id as the primary usage unit.
- If the dashboard exposes friendly session names, the name must come from a
  user-controlled local alias or a configured safe label source. It must not be
  derived from prompts, commands, file paths, repo names, transcript text,
  branch names, ticket ids, user names, or private content.
- Local aliases are optional display metadata, not part of the safe usage event
  schema. They must be stored only in the app-owned local store, remain
  local-only by default, be clearable by the user, and apply to a selected work
  item or technical run group instead of being treated as the title of a whole
  conversation.
- Future account sync must separate token usage data sync from settings sync.
  Enabling usage data sync must not automatically sync local prompt preferences,
  local aliases, dashboard display preferences, or adapter setup preferences.
- Settings sync must support independent modes: local-only settings, sync all
  settings, or sync selected settings. Prompt display-name policy, if enabled,
  is one selectable settings-sync item rather than part of the token usage event
  payload.
- Detailed workflow labels such as `analysis`, `prd_drafting`,
  `code_generation`, `code_review`, `review_response`, `git_commit`,
  `commit_message`, `pull_request`, `workflow_setup`, `ux_copy_review`, or
  other user-defined safe slugs are allowed only when an agent, runtime,
  workflow, or adapter has exact runtime usage metadata and sends the safe
  local event contract.
- `task_type` and `stage` are safe lowercase workflow slugs, not closed enums.
  Spill provides recommended labels, but adapters may define custom reusable
  categories that match `^[a-z][a-z0-9_]{1,40}$`.
- Custom workflow labels must never encode task text, feature names, project
  names, file names, branch names, ticket ids, user names, or private content.
- Usage events include a safe `ai_tool` enum label so users can compare combined
  local usage with per-tool usage for Codex, Claude, and Antigravity/AGY without
  storing prompts, commands, file paths, repo names, logs, diffs, source
  content, environment values, or secrets.
- Direct OpenAI SDK and unknown tool sources may exist for compatibility,
  diagnostics, or future optional integrations, but they are not first-class
  default agent dashboard categories for the local Codex/Claude/Antigravity
  product surface.
- The app should expose a global setup prompt in Preferences and on the web
  setup surface for users who want all projects to report into the same local
  meter. The prompt should tell capable agents to use the one-step setup helper
  for installation or repair instead of asking users to copy or install Codex,
  Claude, and Antigravity/AGY adapters one by one. Direct OpenAI SDK metering
  may be documented as an optional advanced path.
- The global setup prompt must be silent: it must not cause agents to add
  metering status lines to normal replies.
- Local metering must not require a user-facing "start" or "check" action in
  Spill. After the global prompt or adapter is applied, only agents or adapters
  that expose exact runtime usage metadata can write safe local events.
- The global setup prompt is a safety contract, not a runtime hook. If a
  runtime does not expose exact token counts, it must skip event creation
  instead of estimating or reading local logs.
- Runtime hook input contracts are allowed to differ by tool. A hook execution
  means a runtime lifecycle step completed; it does not by itself mean exact
  model token usage is available.
- Antigravity/AGY `PostInvocation` may run for lifecycle or tool steps that
  consume no model tokens and pass empty stdin. Empty stdin must be treated as a
  normal no-event hook call, not as a metering failure and not as a reason to
  invent usage.
- Antigravity/AGY adapters may accept exact token counts from stdin, explicit
  payload JSON arguments, or allowlisted runtime environment fields when a
  runtime exposes those fields to the hook. The adapter must read only fixed
  allowlisted usage keys, must never inspect arbitrary environment values or
  file paths, and must still skip event creation when no exact numeric token
  count is exposed.
- AGY diagnostics must be split into local-only files:
  `antigravity-last-empty.json` for empty no-event hook calls,
  `antigravity-last-mismatch.json` for payloads that exist but do not match a
  supported exact-count shape, and `antigravity-last-success.json` after a
  valid usage event is enqueued. Empty diagnostics must never overwrite
  mismatch or success diagnostics; success must clear stale mismatch and legacy
  `antigravity-latest.json` diagnostics.
- Claude Code uses a different Stop-hook contract: stdin should contain a safe
  payload with `transcript_path`, and the adapter reads exact numeric usage
  from the transcript. Claude diagnostics must be split into
  `claude-last-empty.json`, `claude-last-mismatch.json`, and
  `claude-last-success.json` so hook execution, no-event outcomes, and real
  payload failures are distinguishable.
- Diagnostic files are local support metadata only. They must never store
  prompts, responses, commands, file paths, transcript paths, transcript
  content, payload values, repo names, diffs, logs, source content, environment
  values, secrets, run ids, or span ids.
- Local tool adapters may be installed separately from the prompt when a tool
  exposes exact token-only usage records in local state. Those adapters must
  read only known numeric usage records, such as Codex `token_count` entries,
  and must not parse or store prompts, responses, commands, file paths, working
  directories, diffs, logs, source content, environment values, or secrets.
- Spill should provide a one-step local setup helper that installs detected
  Codex, Claude, and Antigravity/AGY adapter scripts and merges known user-level
  hook config files after an explicit install/fix/apply user request. Direct
  OpenAI SDK metering remains an optional adapter path, not part of the default
  install. Users should not need to run separate install steps per default
  adapter.
- Workflow-level hook setup must be opt-in and target a user-selected hook file
  such as `.agents/hooks.json`; setup must not silently write project workflow
  config files.
- When a trusted workflow script already exposes safe reusable `task_type` or
  `stage` labels, adapters should accept those labels through hook payload,
  command flags, or environment variables instead of inferring labels from
  prompts, commands, logs, source files, or transcripts.
- When a static user-level hook cannot receive per-turn payload fields or
  environment variables, agents may write a short-lived local label context
  containing only `ai_tool`, `task_type`, `stage`, `updated_at`, and
  `expires_at`. Adapters may read that context only for safe reusable labels
  and must ignore expired or tool-mismatched contexts.
- Adapters must not inspect transcripts, logs, command history, or source files
  only to infer workflow labels. If hook payload, environment, or a valid
  short-lived label context does not expose safe `task_type` or `stage` slugs,
  the adapter should use `uncategorized` and the latest safe default stage
  instead.
- Codex metering should support an on-demand local session importer that reads
  recent `~/.codex/sessions/**/rollout-*.jsonl` files when invoked by a trusted
  hook or workflow, converts exact `event_msg/token_count` usage into safe Spill
  events, and deduplicates spans before writing to the local event queue.
- The local dashboard should provide a manual self-test that writes one small
  synthetic token-only event through the local queue, but it must be presented
  as diagnostics rather than the normal startup path.
- The native local token dashboard should run as a separate helper app/process
  from the menu bar control tray when launched from the panel, status menu, or
  Preferences. The helper should appear in normal app switching, including
  Command-Tab/Alt-Tab style switchers, and Command-Q in that helper must quit
  only the dashboard helper process, not the main Spill menu bar app.
- If the helper app is missing in a development build, the main app may fall
  back to the in-process dashboard window, but release app bundles should include
  the helper and use the separate-process path by default.

Dashboard UX requirements:

- The primary dashboard grouping is a human-readable "Work Items" surface, not
  a raw "Runs" surface. A work item is a local aggregate of safe labels over the
  selected time range, derived from `ai_tool`, `task_type`, `stage`, optional
  trusted workflow labels, model id, and timestamp buckets.
- Work item display names should be generated from safe reusable labels, for
  example `Codex - Code generation - Implement` or `Claude Code - Code review -
  Verify`. Raw `run_id` and `span_id` values may appear only in a collapsed
  technical details or diagnostics view.
- If a user assigns a local alias, that alias may override the generated display
  name for the selected work item, but it must not change token totals, safe
  workflow labels, model attribution, or the event payload.
- The default time range should be `Today`, with explicit controls for `7 days`,
  `30 days`, and `All`. The dashboard must make the active accumulation window
  visible near total token KPIs so large all-time totals are not mistaken for
  current work.
- The default agent filter should include only installed first-class agent
  tools: Codex, Claude Code, and Antigravity/AGY. Legacy `unknown` and optional
  direct OpenAI SDK events should be hidden from the default dashboard and
  available only in diagnostics or an explicit advanced filter.
- The dashboard should show model usage from the exact `model` value reported by
  the runtime or adapter. If the runtime does not report a model, the UI should
  show `Model unavailable` rather than guessing from the provider, app, command,
  prompt, or local logs.
- Source breakdown rows must distinguish exact source buckets from runtime-total
  fallback data. When only total counts are exact, the UI should show a label
  such as `Runtime total only`, not `Unknown`, and explain that source buckets
  were not exposed by the runtime.
- Latency must be hidden or labeled `Unavailable` when the runtime did not
  provide exact latency. The dashboard must not present `0 ms` as a real latency
  KPI for events that omitted timing.
- Every summary card, work item table, source breakdown, model breakdown, and
  technical detail panel should have a short info affordance that explains what
  is counted, what is inferred from safe labels, and what is unavailable because
  of the privacy boundary.
- Work item rows must be selectable. Selecting a row should update the detail
  panel with safe aggregates for that work item: total/input/output tokens,
  event count, agent tool, model breakdown, stage breakdown, source breakdown,
  time range, label source, and optional local alias. It must not expose prompts,
  commands, files, repo names, diffs, logs, or source content.
- Technical run details are a diagnostics layer. They are useful for dedupe,
  importer verification, and support, but they are not the default way users
  understand where AI tokens were spent.
- Repeated hook/importer execution for the same exact usage span must not
  inflate totals. If a runtime cannot expose a distinct opaque span cursor, the
  adapter should prefer stable content-free dedupe over counting the same
  numeric payload multiple times.

Acceptance:

- Local token events appear without login when the local queue receives a safe
  event.
- Safe event validation rejects content-like fields.
- Local dashboard shows combined usage and lets users filter by safe AI tool
  labels.
- The default dashboard shows Work Items instead of raw run ids, and raw
  `run_id`/`span_id` values appear only in diagnostics or technical details.
- Work item rows are clickable and update a detail panel with safe local
  aggregates for the selected item.
- Local aliases, if implemented, are local-only display metadata and do not
  change event payloads or cloud-safe schema fields.
- Cloud/account sync options separate usage data sync from settings sync, and
  settings sync can be disabled, all-settings, or selected-settings without
  changing local event ingestion.
- Session or technical run rows are clearly treated as opaque local run groups
  unless a safe local display-name option has been implemented.
- Time-range controls make the accumulation basis explicit, with `Today` as the
  default view and `7 days`, `30 days`, and `All` available.
- Missing model, source, and latency data are labeled as unavailable or runtime
  total fallback instead of appearing as meaningful zeroes or generic unknowns.
- Global setup instructions state that exact counts are required and estimates
  should not be sent.
- Runtime-specific no-event diagnostics such as AGY empty stdin or Claude no
  new token delta are visible as support diagnostics, not counted usage events
  and not dashboard failures.
- UI copy must not imply that a prompt alone can measure token usage.
- Local setup UI offers a one-step installer path before exposing per-adapter
  script and hook snippets.
- Codex usage can be verified with a real `codex exec` run: the Codex session
  importer must store the same exact input/output/reasoning totals that Codex
  reports for the completed turn, without requiring a synthetic usage event.
- The self-test event is local-only, clearly synthetic, uses only numeric
  buckets and enum labels, and can demonstrate non-unknown source breakdowns
  without implying real usage classification.

### 3. System Status Strip

Initial metrics:

- Memory usage
- CPU usage
- Battery percent/state
- Network status

Requirements:

- Read-only pills.
- Compact labels.
- Refresh interval configurable later; use a conservative default.
- Avoid high CPU overhead.

Acceptance:

- Metrics update without blocking UI.
- Missing metrics show a quiet unavailable state.

### 4. AI Status Strip

Initial signals:

- Codex process/session state where locally detectable.
- Claude process/session state where locally detectable.
- Gemini process/session state where locally detectable.
- Ollama running/not running.
- Ollama model hint if cheaply detectable.
- OpenAI API configuration present/missing, without revealing secrets.
- Best-effort tool version and model hints when exposed by local commands or
  visible process arguments.

Requirements:

- No external API calls in MVP unless explicitly configured.
- Never display API keys.
- Treat AI providers as pluggable.
- Show only locally detected or configured tools in the compact panel.
- Hide the AI strip when no local AI tool or OpenAI configuration is detected.
- Treat model and version labels as best-effort hints, not guaranteed session
  truth.

Acceptance:

- AI strip shows useful local state.
- Missing tools do not create errors, noise, or placeholder panel rows.

### 5. Pinned Actions

Requirements:

- Users can pin detected menu bar items or apps.
- Pinned actions show app icon and short label.
- Click order:
  1. Try stored AX action if available.
  2. Try app activation/open fallback.
  3. Show failure state with retry/refresh affordance.

Acceptance:

- Clicking an action never silently fails.
- Users can remove pinned actions.

### 6. Detected Menu Bar Items

Requirements:

- Keep AX scanner best-effort.
- Scan asynchronously.
- Do not promise complete coverage.
- Display detected items as candidates for pinning.

Acceptance:

- Scanner does not freeze UI.
- Scanner message explains limitations.

### 7. Window Quick Actions

Initial actions:

- Left half
- Right half
- Center
- Maximize
- Next display
- Restore previous frame

Requirements:

- Use Accessibility APIs for active window movement.
- Show permission state clearly.
- Keep UI to one compact row.

Acceptance:

- Works on normal resizable windows.
- Fails gracefully on non-resizable/system windows.

## Non-goals

- Recover every hidden menu bar extra.
- Copy every third-party badge/count from the menu bar.
- Read private state from other apps.
- Use private frameworks.
- Create a huge monitoring dashboard.
- Replace dedicated power-user tools in MVP.

## Future Scope

- Plugin/provider system.
- Service integrations:
  - Slack mentions
  - GitHub notifications
  - Calendar next event
  - Gmail unread count
- Custom user scripts.
- Homebrew Cask.
- Optional ScreenCaptureKit experiments for user-approved visual previews.

## Distribution Requirements

Spill should be distributable outside the Mac App Store with Developer ID signing and notarization.

The app should be open source and free by default. Paid support or sponsored builds can be considered later, but core functionality should remain usable without payment.

References:

- Apple Developer ID: https://developer.apple.com/support/developer-id/
- Apple notarization: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- Apple `NSStatusBar`: https://developer.apple.com/documentation/appkit/nsstatusbar
- Apple `NSScreen.safeAreaInsets`: https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets
