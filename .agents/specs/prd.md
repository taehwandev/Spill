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
- If the dashboard exposes friendly session names, the name must come from a
  user-controlled local alias or a configured safe label source. It must not be
  derived from prompts, commands, file paths, repo names, transcript text,
  branch names, ticket ids, user names, or private content.
- Detailed workflow labels such as `analysis`, `prd_drafting`,
  `code_generation`, `code_review`, `ux_copy_review`, or other user-defined
  safe slugs are allowed only when an agent, runtime, workflow, or adapter has
  exact runtime usage metadata and sends the safe local event contract.
- `task_type` and `stage` are safe lowercase workflow slugs, not closed enums.
  Spill provides recommended labels, but adapters may define custom reusable
  categories that match `^[a-z][a-z0-9_]{1,40}$`.
- Custom workflow labels must never encode task text, feature names, project
  names, file names, branch names, ticket ids, user names, or private content.
- Usage events include a safe `ai_tool` enum label so users can compare combined
  local usage with per-tool usage for Codex, Claude, Antigravity/AGY,
  direct OpenAI, and unknown tool sources without storing prompts, commands, file
  paths, repo names, logs, diffs, source content, environment values, or
  secrets.
- The app should expose a global setup prompt in Preferences and on the web
  setup surface for users who want all projects to report into the same local
  meter.
- The global setup prompt must be silent: it must not cause agents to add
  metering status lines to normal replies.
- Local metering must not require a user-facing "start" or "check" action in
  Spill. After the global prompt or adapter is applied, only agents or adapters
  that expose exact runtime usage metadata can write safe local events.
- The global setup prompt is a safety contract, not a runtime hook. If a
  runtime does not expose exact token counts, it must skip event creation
  instead of estimating or reading local logs.
- Local tool adapters may be installed separately from the prompt when a tool
  exposes exact token-only usage records in local state. Those adapters must
  read only known numeric usage records, such as Codex `token_count` entries,
  and must not parse or store prompts, responses, commands, file paths, working
  directories, diffs, logs, source content, environment values, or secrets.
- Spill should provide a one-step local setup helper that installs detected
  Codex, Claude, Antigravity/AGY, and direct OpenAI adapter scripts and merges
  known user-level hook config files only after explicit user action.
- Workflow-level hook setup must be opt-in and target a user-selected hook file
  such as `.agents/hooks.json`; setup must not silently write project workflow
  config files.
- When a trusted workflow script already exposes safe reusable `task_type` or
  `stage` labels, adapters should accept those labels through hook payload,
  command flags, or environment variables instead of inferring labels from
  prompts, commands, logs, source files, or transcripts.
- Adapters must not inspect transcripts, logs, command history, or source files
  only to infer workflow labels. If a hook payload does not expose safe
  `task_type` or `stage` slugs, the adapter should use `uncategorized` and the
  latest safe default stage instead.
- Codex metering should support an on-demand local session importer that reads
  recent `~/.codex/sessions/**/rollout-*.jsonl` files when invoked by a trusted
  hook or workflow, converts exact `event_msg/token_count` usage into safe Spill
  events, and deduplicates spans before writing to the local event queue.
- The local dashboard should provide a manual self-test that writes one small
  synthetic token-only event through the local queue, but it must be presented
  as diagnostics rather than the normal startup path.

Acceptance:

- Local token events appear without login when the local queue receives a safe
  event.
- Safe event validation rejects content-like fields.
- Local dashboard shows combined usage and lets users filter by safe AI tool
  labels.
- Session rows are clearly treated as opaque local run groups unless a safe
  local display-name option has been implemented.
- Global setup instructions state that exact counts are required and estimates
  should not be sent.
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
