# Spill PRD

## Summary

Spill is a compact macOS control tray for people whose menu bar is crowded,
especially on notched MacBooks.

It does not try to force macOS to reveal or rearrange every hidden menu bar
icon. Instead, Spill provides a small, fast panel that combines:

- pinned menu bar and app actions;
- system status;
- AI/tooling status, including local token usage;
- quick window actions;
- optional local dashboard and web dashboard surfaces for deeper token metering.

The product should feel closer to a tiny native utility tray than a dashboard.
Detailed views are allowed, but they must remain secondary entry points from the
compact tray, Preferences, or web portal.

## Problem

macOS menu bar space is limited. On notched MacBooks, menu bar extras can
disappear behind the notch or be hidden by the system. Apple does not provide a
public API to enumerate, clone, reorder, resize, or reveal every third-party
menu bar extra.

AI-heavy users also run multiple local agents and API tools. They need a local,
privacy-preserving way to understand usage without sending prompts, commands,
source files, logs, or repository context to a server.

Users still need quick access to two kinds of information:

- actionable icons that mostly serve as shortcuts;
- status indicators such as memory, CPU, battery, network, AI agent state,
  local token usage, or unread/work state.

Existing solutions often rely on fragile spacer tricks, private APIs, large
dashboards, or separate apps for each small utility.

## Product Positioning

Spill is:

- a small Mac control tray;
- a menu bar action shelf;
- a glanceable system and AI status strip;
- a light window-action launcher;
- a local-first AI token usage meter;
- an optional encrypted aggregate backup and web dashboard.

Spill is not:

- a full iStat Menus clone;
- a full Rectangle clone;
- a full Raycast clone;
- a guaranteed menu bar icon restoration tool;
- a private API menu bar hack;
- a cloud-first analytics SDK;
- a prompt, command, repository, transcript, or source-code collector.

## Target Users

- MacBook users with a notch.
- Developers and AI-heavy users.
- Users with crowded menu bars.
- Users who run tools like Rectangle, iStat Menus, Hidden Bar, Ice, Raycast,
  Hammerspoon, Ollama, Codex, Claude Code, Antigravity/AGY, or local agents.
- Users who prefer a small native utility over a large always-open dashboard.
- Users who want optional web aggregate statistics without giving Spill access
  to private work content.

## Core Principles

1. **Always visible trigger**
   Spill keeps one small menu bar trigger. No giant spacer.

2. **Glance first**
   The panel should answer "what is happening?" in one second.

3. **Actionable by default**
   Items should be clickable, not decorative.

4. **Best-effort is honest**
   If a third-party menu bar action cannot be pressed, show a fallback.

5. **Local first**
   Core token metering and tray behavior must work without login, cloud upload,
   telemetry, or a web dashboard.

6. **Small surface area**
   The panel is compact. Deep configuration belongs in Preferences. Detailed
   token metering belongs in the local dashboard helper or web portal.

7. **Open-source distributable**
   Avoid private APIs and fragile system hooks.

8. **Content-free metering**
   Token usage features may count safe numeric and categorical data, but must
   not collect prompts, responses, commands, file paths, repo names, branch
   names, terminal output, logs, diffs, source content, environment values, or
   secrets.

## MVP Scope

### 1. Single Menu Bar Trigger

Requirements:

- A single fixed-width `...` or Spill icon appears in the menu bar.
- Left click toggles Spill Panel.
- Right click or Control-click opens a native menu with:
  - Show/Hide Spill Panel
  - Open Local Token Dashboard
  - Refresh
  - Check for Updates
  - Preferences
  - Quit
- No spacer-based layout manipulation.

Acceptance:

- The trigger remains small.
- Local token usage appears inside the panel AI section.
- No invisible or oversized status items are created.
- The app remains usable when the menu bar is crowded, subject to macOS status
  item limitations.

### 2. First-Run And Onboarding

Requirements:

- First launch opens the compact panel or a lightweight welcome state that
  explains the tray trigger, compact panel, and local-first privacy model.
- Users can continue without account creation.
- Accessibility permission is requested only when the user enables or invokes a
  feature that needs it, such as window actions or best-effort menu bar item
  scanning.
- Token metering setup is offered as an optional setup card in Preferences and
  the local token dashboard. It should explain what is counted, what never
  leaves the device, and why exact runtime usage metadata is required.
- The global setup prompt and one-step installer should be available, but the UI
  must not imply that a prompt alone can measure token usage.
- Web dashboard connection is optional and clearly separate from local metering.

Acceptance:

- A new user can understand the tray and open Preferences without granting
  Accessibility permission.
- Token metering setup is discoverable without being mandatory.
- Permission prompts are tied to the feature that requires them.
- The onboarding copy does not imply cloud upload, prompt collection, or
  realtime sync.

### 3. Compact Spill Panel

Requirements:

- Native `NSPanel`, non-activating where appropriate.
- Appears under the notch when notch geometry is available, otherwise under or
  near the trigger.
- Glass tray style.
- Height target: 120-180px for MVP.
- Sections:
  - Status Strip
  - AI Strip
  - Pinned Actions
  - Window Actions
  - Detected Items, optionally collapsed
- The AI Strip includes the token metering summary as one compact AI usage
  affordance, not a separate dashboard embedded in the panel.

Acceptance:

- Panel opens within 1 second.
- Text and icons do not overlap.
- Panel does not feel like a full dashboard.
- The token summary can open the local token dashboard helper.

### 4. Local Token Metering

Requirements:

- The native app reads safe token usage from an app-owned local store.
- Token metering works without login, cloud upload, telemetry, or a running web
  app.
- Local usage records may include only numeric counts, timestamps, model ids,
  opaque ids, latency, source buckets, safe `ai_tool`, `task_type`, and `stage`
  labels.
- Local usage records must never include prompts, responses, commands, file
  paths, repo names, branch names, terminal output, logs, diffs, source content,
  environment values, secrets, or arbitrary content-like fields.
- Setup UI should offer a one-step installer path before exposing per-adapter
  snippets.
- The local dashboard should group usage into human-readable Work Items derived
  from safe labels, not raw run ids.
- Raw `run_id` and `span_id` values may appear only in diagnostics or collapsed
  technical details.
- Local aliases, if supported, are local-only display metadata. They do not
  change token totals, safe labels, event payloads, or cloud-safe schemas.
- Missing model, source, or latency values must be labeled as unavailable or
  runtime-total fallback instead of presented as meaningful zeroes.
- A self-test may create synthetic token-only data, but must be clearly labeled
  as diagnostics.

Dashboard UX requirements:

- Default time range is `Today`, with explicit `7 days`, `30 days`, and `All`
  controls.
- Default agent filter includes first-class local agent tools such as Codex,
  Claude Code, and Antigravity/AGY. Legacy `unknown` and optional direct OpenAI
  SDK events belong behind diagnostics or an advanced filter.
- Work item rows are selectable and update a detail panel with safe aggregates:
  total/input/output tokens, event count, agent tool, model breakdown, stage
  breakdown, source breakdown, time range, label source, and optional local
  alias.
- Every summary card, work item table, source breakdown, model breakdown, and
  technical detail panel has a short info affordance explaining what is counted,
  what is inferred from safe labels, and what is unavailable due to the privacy
  boundary.

Acceptance:

- Local token events appear without login when the local store receives a safe
  event.
- Safe event validation rejects content-like fields.
- Local dashboard shows combined usage and lets users filter by safe AI tool
  labels.
- Work item rows are clickable and update a safe detail panel.
- UI copy states that exact counts are required and estimates should not be
  sent.
- Runtime hook, importer, diagnostics, dedupe, queue, and tool-specific adapter
  mechanics live in ARD and adapter docs, not this PRD.

### 5. System Status Strip

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

### 6. AI Status Strip

Initial signals:

- Codex process/session state where locally detectable.
- Claude process/session state where locally detectable.
- Gemini process/session state where locally detectable.
- Ollama running/not running.
- Ollama model hint if cheaply detectable.
- OpenAI API configuration present/missing, without revealing secrets.
- Local token metering summary.
- Best-effort tool version and model hints when exposed by local commands or
  visible process arguments.

Layout requirements:

- The strip is a compact cluster of AI tool status pills plus one token usage
  summary pill.
- The token summary appears in the same AI strip, after local tool status, and
  may wrap to a second compact line only when the panel width requires it.
- Clicking the token summary opens the local token dashboard helper.
- If no AI tool is detected but token metering data exists, the AI strip remains
  visible with the token summary.

Behavior requirements:

- No external API calls in MVP unless explicitly configured.
- Never display API keys.
- Treat AI providers as pluggable.
- Show only locally detected or configured tools in the compact panel.
- Hide the AI strip only when no local AI tool, OpenAI configuration, or token
  metering state exists.
- Treat model and version labels as best-effort hints, not guaranteed session
  truth.

Acceptance:

- AI strip shows useful local state.
- Token metering placement is visually and conceptually part of AI status.
- Missing tools do not create errors, noise, or placeholder panel rows.

### 7. Pinned Actions And Pin Management

Requirements:

- Users can pin detected menu bar items or apps.
- Pinned actions show app icon and short label.
- MVP compact panel shows up to 8 pinned actions.
- Pin/unpin is available directly from visible detected action tiles.
- Preferences provides a Pin Management view for:
  - removing pinned actions;
  - reordering pinned actions;
  - refreshing stale detected items;
  - explaining fallback behavior.
- Click order:
  1. Try stored Accessibility action if available.
  2. Try app activation/open fallback.
  3. Show failure state with retry/refresh affordance.

Acceptance:

- Clicking an action never silently fails.
- Users can remove pinned actions.
- Users can reorder pinned actions in Preferences.
- If more than 8 actions are pinned, the compact panel shows the first 8 and
  directs overflow management to Preferences.

### 8. Detected Menu Bar Items

Requirements:

- Keep Accessibility scanner best-effort.
- Scan asynchronously.
- Do not promise complete coverage.
- Display detected items as candidates for pinning.
- Explain that some third-party menu bar items cannot be detected or invoked
  through public APIs.

Acceptance:

- Scanner does not freeze UI.
- Scanner message explains limitations.

### 9. Window Quick Actions

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

### 10. Web Portal And Private Usage Upload

Requirements:

- Web portal is an optional companion for account connection, install guidance,
  device overview, settings, and encrypted aggregate usage statistics.
- Local app remains fully usable when the user never signs in.
- Web login completes in the browser and returns to the app through a callback
  or deep link.
- The app receives a write-only device upload credential, not OAuth access or
  refresh tokens.
- Private Usage Upload is opt-in.
- The app uploads only end-to-end encrypted, pre-aggregated usage buckets
  through a Spill relay API.
- The app never writes directly to the database, object storage, or vendor SDK.
- The native app never downloads cloud usage data.
- MVP upload cadence is daily and opportunistic: previous-day sealed buckets
  upload the next time the user is active and network is available.
- Manual Sync Now performs one explicit upload attempt.
- Multi-day backlogs, such as weekends or offline periods, remain queued locally
  and may upload later in one or more batches.
- The web dashboard shows per-device statistics and combined account totals
  after browser-side decryption.
- The web dashboard must label delayed data as last backed up, not realtime
  presence.

Acceptance:

- Web portal requirements are documented before implementation work continues.
- Cloud upload can be disabled without affecting local metering.
- No raw events or content-like data are uploaded.
- Server-side plaintext token totals are not required for the web dashboard.
- Detailed upload cadence, E2EE key custody, storage backend, and retry policy
  are specified in `.agents/runs/private-usage-upload/01-prd.md` and the
  follow-on ARD.

### 11. Update UX

Requirements:

- Users can check for updates from the status menu and Preferences.
- Preferences shows current version, latest known version, last check time, and
  update state.
- Update states include not checked, checking, up to date, update available,
  download opened, failed, and unavailable.
- Release notes and download/install actions must be explicit user actions.
- Automatic installation is not required for MVP.
- Sparkle appcast support may be used only when signing, notarization, appcast,
  and key management are ready.

Acceptance:

- Manual update check has a visible success or failure state.
- Update failures are redacted and actionable.
- Update UX does not imply signed automatic updates before release
  infrastructure exists.

### 12. Telemetry Policy

Requirements:

- Telemetry is optional and must not be required for app functionality.
- The default open-source build should send no telemetry unless an app telemetry
  key is explicitly configured.
- Telemetry events may include only coarse product events and safe enum/string
  props such as panel opened, setting changed, update check result, or pin
  toggled.
- Telemetry must never include prompts, responses, commands, file paths, repo
  names, branch names, terminal output, logs, diffs, source content, environment
  values, secrets, token payloads, local aliases, or raw usage events.
- Users and test environments must have a clear opt-out path.

Acceptance:

- The PRD states what telemetry may and may not collect.
- Telemetry remains content-free and separate from token usage metering.
- Smoke tests can disable telemetry.

## Non-goals

- Recover every hidden menu bar extra.
- Copy every third-party badge/count from the menu bar.
- Read private state from other apps.
- Use private frameworks.
- Create a huge monitoring dashboard in the compact panel.
- Replace dedicated power-user tools in MVP.
- Make cloud account connection mandatory.
- Upload raw token events or private work content.
- Use telemetry as a usage metering path.

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
- Paid multi-device or higher-frequency encrypted aggregate upload.
- Account key recovery for private usage upload.
- Signed Sparkle appcast updates after Developer ID release infrastructure is
  ready.

## Distribution Requirements

Spill should be distributable outside the Mac App Store with Developer ID
signing and notarization.

The app should be open source and free by default. Paid support, sponsored
builds, or paid higher-frequency/multi-device web features can be considered
later, but core local functionality should remain usable without payment.

References:

- Apple Developer ID: https://developer.apple.com/support/developer-id/
- Apple notarization:
  https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- Apple `NSStatusBar`: https://developer.apple.com/documentation/appkit/nsstatusbar
- Apple `NSScreen.safeAreaInsets`: https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets
- Private Usage Upload PRD: `.agents/runs/private-usage-upload/01-prd.md`
  (follow-on feature scope)
- Local token metering architecture: `.agents/specs/ard.md`
