# Detailed ARD: Power Footer And Sleep Guard

## Architecture Summary

Add two settings to `SpillSettings` and introduce a `SleepGuardController` owned by `AppDelegate`. The controller wraps an injectable assertion manager so production code uses public IOKit power assertions while tests use a fake manager. `SpillBarView` observes the controller and renders a compact footer menu for duration selection and stop. `SystemStatusStore` skips power reads when the power footer is hidden.

## Decisions

### D1: Sleep Guard is a control, not a status meter

Decision: Render Sleep Guard in the footer as a small menu control.

Rationale: It changes system behavior and should be managed separately from passive CPU and memory meters.

Alternatives considered: Add Sleep Guard to the status module list. That would confuse passive status with active controls.

### D2: No extra macOS status item

Decision: Keep Sleep Guard inside the existing Spill panel.

Rationale: The product direction is one status item because additional status items worsen notch crowding.

Alternatives considered: Add a separate awake icon to the menu bar. That conflicts with the single-trigger architecture.

### D3: Use injectable IOKit assertion management

Decision: Wrap IOKit assertion creation and release behind a protocol.

Rationale: The real API affects system power behavior and must be testable without creating assertions in unit tests.

Alternatives considered: Call IOKit directly from the view. That would make tests and lifecycle cleanup fragile.

## Modules Affected

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/App/SleepGuardController.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Preferences/PowerPreferencesSection.swift`
- `Sources/Spill/Preferences/PreferencesView.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Tests/SpillTests/SleepGuardControllerTests.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`

## New Types / APIs

- `SleepGuardDuration` for fixed durations.
- `SleepGuardController` observable object.
- `SleepAssertionManaging` protocol.
- `IOKitSleepAssertionManager` production implementation.
- `SpillSettings.showPowerFooter`.
- `SpillSettings.sleepGuardKeepsDisplayAwake`.

## Data Flow

```text
Preferences power setting -> SystemStatusStore power refresh gate
Preferences power setting -> SpillBarView footer visibility
SpillBarView duration menu -> SleepGuardController.start
SleepGuardController -> SleepAssertionManaging -> IOKit assertion
Timer ticks -> remaining time -> SpillBarView footer label
Stop or expiry -> SleepGuardController.stop -> assertion release
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: not used.
- Network: not used.
- File system: UserDefaults only.

## Failure Modes

- System assertion creation fails: remain off and store a short error message.
- Display assertion creation fails after system assertion succeeds: release the system assertion and remain off.
- App termination: stop Sleep Guard and release assertions.
- Timer drift: remaining time is recalculated from the expiration date, not decremented blindly.

## Performance Notes

- No timer runs while off.
- Active timer ticks once per second for the footer label.
- IOKit calls happen only on start and stop.

## Test Strategy

### Automated

- Settings tests cover power footer and display-awake defaults and persistence.
- Sleep Guard tests cover start, stop, expiry, failure rollback, and display assertion behavior.

### Manual

- Open panel and select a Sleep Guard duration.
- Confirm the footer shows remaining time.
- Stop Sleep Guard and confirm the footer returns to off.
- Toggle power footer visibility in Preferences.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Settings and docs | Builder | settings, run docs, settings tests | Yes |
| Sleep Guard controller | Builder | controller and controller tests | Yes |
| Panel and preferences UI | Builder | panel, panel controller, preferences | After controller API |
| Verification and closeout | Verifier | run verification docs and roadmap | No |

## Risks

- Assertion semantics differ by hardware and power state. Public API limits should be clear in UI help text.
- Display awake behavior can drain battery, so it remains opt-in.
