# Detailed ARD: Stitch-Inspired Panel Shell

## Architecture Summary

The panel remains an AppKit `NSPanel` hosted through `NSHostingView`, with the visible content implemented in SwiftUI. The Stitch reference is translated into native sections inside `SpillBarView`: header, status meters, action strip, and footer. Data still flows from `SpillSettings`, `AccessibilityPermission`, and `AXMenuBarItemScanner`; this slice does not add providers or external data sources.

## Decisions

### D1: Implement the Stitch Reference as Native SwiftUI

Decision:

Use the Stitch screen as a layout and visual reference, then implement the panel with native SwiftUI components inside the existing NSPanel.

Rationale:

The app is a native macOS utility and already has an NSPanel host. Native controls preserve accessibility, reduce runtime complexity, and keep distribution safer than embedding generated HTML.

Alternatives considered:

- Embed a web view for the Stitch HTML output. Rejected because it would add an unnecessary runtime surface and complicate native action handling.
- Keep the previous icon-only tray. Rejected because it does not expose state and does not match the current product direction.

### D2: Render Only Real Current State

Decision:

Use `ACCESS` and `ACTIONS` meters as temporary real-state rows instead of copying the Stitch CPU and memory examples.

Rationale:

The app does not yet have system monitoring providers. Rendering fake metrics would make the open-source project misleading and make verification weaker.

Alternatives considered:

- Add placeholder CPU and memory rows. Rejected because the user explicitly cares about whether the displayed state is real and useful.
- Hide all status rows until providers exist. Rejected because Accessibility and action availability are already meaningful states.

### D3: Keep Layout Compact and Notch-Aware

Decision:

Use a fixed compact panel width and a taller shell height, while preserving the existing notch-centered frame calculation.

Rationale:

The shell needs vertical room for state and actions, but should still feel like a menu bar surface instead of a dashboard. Anchoring remains delegated to `SpillPanelLayout` and `MenuBarNotchGeometry`.

Alternatives considered:

- Size the panel based on item count. Rejected for this shell because a stable width prevents layout churn and keeps the status sections predictable.
- Expand into a dashboard. Rejected because the product direction is compact and always-nearby.

## Modules Affected

- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Panel/SpillPanelLayout.swift`
- `Sources/Spill/Panel/SpillPanelMetrics.swift`
- `.agents/runs/stitch-panel-shell/`
- `.agents/design/stitch.md`

## New Types / APIs

- `SpillPanelState`: private view state for permission, scanning, empty, and ready conditions.
- `SpillActionButton`: private SwiftUI action tile for `MenuBarItemSnapshot`.
- No public API is introduced.

## Data Flow

```text
SpillSettings plus AXMenuBarItemScanner plus AccessibilityPermission
  -> SpillBarView displayItems and SpillPanelState
  -> status meters, inline states, action strip, footer
  -> scanner.pressItem(withID:) for user actions
```

## Permissions

- Accessibility: read existing trust state and use existing scanner action execution.
- Screen Recording: not used.
- Network: not used.
- File system: not used.

## Failure Modes

- Accessibility denied: panel shows permission-required state and no fake data.
- Scanner active with no results yet: panel shows scanning state.
- Scanner returns no display items: panel shows the correct empty state for the current display mode.
- Item cannot be pressed: action tile is disabled and dimmed.
- Unsupported symbol on older macOS: SF Symbols render fallback behavior is handled by the system.

## Performance Notes

- No polling, timers, network calls, or screen capture are added.
- Panel width no longer grows with item count; overflow stays inside a horizontal scroller.
- View computation remains based on current observed objects.

## Test Strategy

### Automated

- `swift build`
- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py run-gates`
- `python3 .agents/scripts/workflow.py language-gates`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- Source scan for fake system metrics in panel code and run docs.

### Manual

- Launch the app.
- Open the menu bar trigger.
- Confirm permission, scanning, empty, and populated states as available on the test machine.
- Confirm the panel remains compact and action tiles do not overlap text.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Stitch mapping and run docs | Product | `.agents/runs/stitch-panel-shell/`, `.agents/design/stitch.md` | Yes |
| Native panel shell | Builder | `Sources/Spill/Panel/SpillBarView.swift`, `Sources/Spill/Panel/SpillPanelController.swift`, `Sources/Spill/Panel/SpillPanelMetrics.swift`, `Sources/Spill/Panel/SpillPanelLayout.swift` | Yes after mapping |
| Verification | Verifier | No write scope except run closeout | Yes after build |

## Risks

- Without real providers, status rows are intentionally limited to current app state.
- Manual visual verification on a notched Mac may still reveal spacing tweaks.
- Future providers may require a small layout refresh once real system and AI state models are connected.
