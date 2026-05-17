# Detailed ARD: Startup Permission Timeout

## Architecture Summary

Keep startup work independent from optional Accessibility-dependent focused
window lookup. `WindowActionStore` now starts from plain permission state,
queries the focused window only on trusted refresh paths, and accepts an
injectable focused-window controller for tests.

## Decisions

### D1: No Focused-Window Read During Initialization

Decision:

Initialize window actions from permission state and static display availability,
but do not call `focusedWindowFrame()` from `WindowActionStore.init`.

Rationale:

`WindowActionStore` is constructed during app startup. Focused-window reads use
Accessibility and are optional for launch, so they must not sit on the critical
path.

Alternatives considered:

- Keep eager refresh and add a timeout: still keeps optional AX work on startup.
- Disable window actions entirely until panel open: safer but less accurate on
  trusted systems after refresh.

### D2: Trust Gate Before AX Window Lookup

Decision:

Check an injected Accessibility trust reader before focused-window refresh and
perform paths.

Rationale:

When the app is untrusted, AX lookup is guaranteed to be unproductive and can
trigger slow or noisy system behavior. The store can present explicit
permission-required states without touching the controller.

Alternatives considered:

- Let `FocusedWindowController` reject untrusted calls: correct result, but it
  still allows callers to put controller work on the wrong path.

### D3: Retry Panel Accessibility Smoke Report

Decision:

Allow the panel layout smoke test to wait briefly for SwiftUI accessibility
labels to appear before printing final diagnostics.

Rationale:

Removing launch-time focused-window work can make startup faster. The smoke test
should validate the real panel state after accessibility labels settle rather
than fail because diagnostics were sampled too early.

Alternatives considered:

- Remove accessibility validation: loses an important regression check.
- Increase only the script timeout: does not change when diagnostics are
  sampled.

## Modules Affected

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Providers/WindowActionProvider.swift`
- `Tests/SpillTests/WindowActionStoreTests.swift`
- `scripts/verify-panel-layout-smoke.sh`

## New Types / APIs

```swift
@MainActor
protocol FocusedWindowControlling: AnyObject {
    func focusedWindowFrame() -> CGRect?
    func perform(
        _ kind: WindowActionKind,
        restoreHistory: inout WindowFrameRestoreHistory
    ) -> SpillActionResult
}
```

`WindowActionStore` also accepts an injectable `AccessibilityTrustReader`.

## Data Flow

```text
app startup -> WindowActionStore init -> plain permission state -> panel actions
trusted refresh -> FocusedWindowControlling -> window action state
untrusted perform -> permission-required result -> no controller call
```

## Permissions

- Accessibility: required only for focused-window lookup and window movement,
  not for startup.
- Screen Recording: unchanged.
- Network: unchanged.
- File system: unchanged.

## Failure Modes

- Accessibility untrusted: actions show permission-required and perform returns
  `.permissionRequired("Accessibility")`.
- No focused window: trusted refresh disables window actions with "No focused
  window".
- SwiftUI accessibility labels settle late in smoke mode: diagnostics retry
  briefly before final failure.

## Performance Notes

- Removes optional AX focused-window work from launch.
- Adds no new polling.
- Extends only the panel layout smoke process timeout from 1.2s to 2.0s.

## Test Strategy

### Automated

- `swift test`
- `swift build`
- `./scripts/build-app.sh`
- `./scripts/verify-runtime-smoke.sh`
- `./scripts/verify-panel-open-smoke.sh`
- `./scripts/verify-panel-layout-smoke.sh`
- `python3 .agents/scripts/workflow.py verify`
- `git diff --check`

### Manual

- Launch Spill without relying on Accessibility permission.
- Open the panel and confirm permission-required states remain visible instead
  of blocking launch.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Startup gating | builder | `WindowActionProvider.swift`, `WindowActionStoreTests.swift` | no |
| Smoke stabilization | builder | `AppDelegate.swift`, `verify-panel-layout-smoke.sh` | no |
| Verification | verifier | command checks | no |

## Risks

- A trusted launch may initially show conservative disabled window states until
  refresh occurs.
- The real macOS timeout reported by the maintainer may involve another optional
  system call; this slice removes the identified focused-window AX startup risk.
