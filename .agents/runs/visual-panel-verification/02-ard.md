# Detailed ARD: Visual Panel Verification

## Architecture Summary

Extend the existing smoke mode with an optional panel layout validation flag. `AppDelegate` opens the panel, asks `SpillPanelController` for a layout report, and prints structured success/failure markers. A new shell script builds the app, runs smoke mode with the layout flag, and verifies the markers.

## Decisions

### D1: Use AppKit geometry instead of screenshots

Decision: Validate panel frame and content bounds from inside the app.

Rationale: Screenshot comparison can require Screen Recording permission and is brittle across displays, wallpapers, scale factors, and window server state. Geometry checks catch the first class of compact layout regressions without new permissions.

Alternatives considered: Pixel screenshots were deferred. Accessibility tree inspection was deferred because it may require additional trust configuration.

### D2: Keep the check smoke-only

Decision: Run layout validation only when `SPILL_SMOKE_VALIDATE_PANEL_LAYOUT=1`.

Rationale: Production behavior should not change and users should not pay runtime cost for verification-only logic.

Alternatives considered: Always logging panel geometry was rejected because it adds noise and no user value.

## Modules Affected

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `scripts/verify-panel-layout-smoke.sh`
- `.agents/scripts/workflow.py`
- `.agents/README.md`

## New Types / APIs

```swift
struct SpillPanelLayoutReport {
    let isVisible: Bool
    let frame: NSRect
    let contentBounds: NSRect
    let visibleFrame: NSRect
    let isValid: Bool
    let logLine: String
}
```

## Data Flow

```text
smoke env -> AppDelegate -> SpillPanelController.show() -> layout report -> stdout marker -> shell verifier
```

## Permissions

- Accessibility: not required.
- Screen Recording: not required.
- Network: not required.
- File system: shell script writes only a temporary log file.

## Failure Modes

- App fails to launch: script fails and prints log.
- Panel is not visible: script fails.
- Panel frame is invalid or too large: app prints failure marker and script fails.
- Report marker missing: script fails.

## Performance Notes

- The check runs only in smoke mode.
- It uses existing app startup and panel-open paths.
- No timers are added outside the existing smoke exit timer.

## Test Strategy

### Automated

- `swift build`
- `swift test`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`
- Existing smoke and workflow gates.

### Manual

- Manual visual inspection remains useful but is not required for this automated geometry slice.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| App report | Builder | `Sources/Spill/App/AppDelegate.swift`, `Sources/Spill/Panel/SpillPanelController.swift` | No |
| Workflow command | Builder | `scripts/verify-panel-layout-smoke.sh`, `.agents/scripts/workflow.py`, `.agents/README.md` | Yes after marker names are stable |
| Verification docs | Verifier | `.agents/runs/visual-panel-verification/05-verification.md`, `.agents/runs/visual-panel-verification/06-closeout.md` | Yes after implementation |

## Risks

- Geometry checks do not catch all visual issues such as text overlap or color contrast.
- Future screenshot tests may still need manual permission setup.
