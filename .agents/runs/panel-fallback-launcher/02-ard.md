# Detailed ARD: Panel Fallback Launcher

## Architecture Summary

The existing `SpillPanelController` remains the single owner of panel presentation. `AppDelegate` exposes explicit show and toggle paths, configures a normal app menu, and passes a show-panel closure into preferences. A new SwiftUI preferences section renders the fallback controls and calls the existing scanner and permission utilities directly for refresh and settings access.

## Decisions

### D1: Use Preferences as the Visible Fallback

Decision:

Add the fallback launcher to preferences instead of adding another status item or floating window.

Rationale:

Preferences already opens during setup, can become a normal app window, and is visible even if the status item is difficult to find.

Alternatives considered:

- Add a second menu bar item. Rejected because it worsens menu bar crowding.
- Add a floating launcher. Deferred because it adds visual noise and new placement behavior.

### D2: Add Normal App Menu Commands

Decision:

Configure a simple app menu with panel, refresh, preferences, and quit commands.

Rationale:

When Spill is active as a regular app, the menu bar should provide a native fallback path. This is public AppKit behavior and does not affect other apps' menu bar items.

Alternatives considered:

- Rely only on the global hotkey. Rejected because the shortcut is easy to miss during setup.

### D3: Keep Panel Presentation Centralized

Decision:

Preferences receives a closure that calls `AppDelegate.showSpillBar()`.

Rationale:

This avoids duplicating panel ownership and keeps status item refresh behavior in one place.

Alternatives considered:

- Pass `SpillPanelController` into SwiftUI preferences. Rejected because it leaks AppKit panel ownership into view code.

## Modules Affected

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Preferences/PreferencesView.swift`
- `Sources/Spill/Preferences/PreferencesWindowController.swift`
- `Sources/Spill/Preferences/PanelFallbackPreferencesSection.swift`
- `.agents/runs/panel-fallback-launcher/`

## New Types / APIs

- `PanelFallbackPreferencesSection`
- `PreferencesWindowController.init(settings:scanner:showPanelAction:)`
- `PreferencesView.showPanelAction`
- App menu selector methods in `AppDelegate`

## Data Flow

```text
Preferences button
  -> showPanelAction closure
  -> AppDelegate.showSpillBar()
  -> SpillPanelController.show()
  -> StatusItemController refresh
```

```text
App menu command
  -> AppDelegate selector
  -> existing panel, refresh, preferences, or quit path
```

## Permissions

- Accessibility: existing trust check, request, and settings link only.
- Screen Recording: not used.
- Network: not used.
- File system: not used.

## Failure Modes

- Accessibility denied: refresh control disables and settings button remains available.
- Status item hidden: preferences and app menu still open the panel.
- Panel already visible: open action keeps it visible.
- Scanner already running: refresh button disables while scanning.

## Performance Notes

- No new timers or background tasks are added.
- Preferences state reads existing observed scanner values.

## Test Strategy

### Automated

- `swift build`
- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `git diff --check`

### Manual

- Launch app.
- Open preferences.
- Click `Open Panel`.
- Confirm the panel appears even if the status item is not used.
- Confirm refresh disables when Accessibility is not trusted.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Run documentation | Product | `.agents/runs/panel-fallback-launcher/` | Yes |
| App menu and show-panel path | Builder | `Sources/Spill/App/AppDelegate.swift` | Yes after scope is fixed |
| Preferences fallback section | Builder | `Sources/Spill/Preferences/PreferencesView.swift`, `Sources/Spill/Preferences/PreferencesWindowController.swift`, `Sources/Spill/Preferences/PanelFallbackPreferencesSection.swift` | Yes after closure API is agreed |
| Verification | Verifier | run closeout docs | After implementation |

## Risks

- Manual visual verification is still needed to confirm panel placement on the target notched Mac.
- Future menu bar agent packaging may revisit whether Spill is regular, accessory, or hybrid.
