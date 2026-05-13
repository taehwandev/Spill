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
  - Refresh
  - Preferences
  - Quit
- No spacer-based layout manipulation.

Acceptance:

- The trigger remains small.
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
  - Pinned Actions
  - Detected Items, if useful

Acceptance:

- Panel opens within 1 second.
- Text and icons do not overlap.
- Panel does not feel like a full dashboard.

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
- Ollama running/not running.
- Ollama model hint if cheaply detectable.
- OpenAI configuration present/missing, without revealing secrets.

Requirements:

- No external API calls in MVP unless explicitly configured.
- Never display API keys.
- Treat AI providers as pluggable.

Acceptance:

- AI strip shows useful local state.
- Missing tools do not create errors or noise.

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
- Sparkle updates.
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
