# Closeout: Power Footer And Sleep Guard

## Summary

Added a compact Sleep Guard footer control and a power footer visibility option. Sleep Guard is off by default, starts only after selecting a fixed duration, displays remaining time while active, and releases assertions on stop, expiry, or app termination. Hidden power footer state now skips power provider reads.

## Changed Files

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/App/SleepGuardController.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Preferences/PowerPreferencesSection.swift`
- `Sources/Spill/Preferences/PreferencesView.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Tests/SpillTests/SleepGuardControllerTests.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`
- `Tests/SpillTests/SystemStatusStoreTests.swift`

## Verification

- Passed: `swift build`
- Passed: `swift test`
- Passed: `python3 .agents/scripts/workflow.py verify`
- Passed: `python3 .agents/scripts/workflow.py runtime-smoke`
- Passed: `python3 .agents/scripts/workflow.py panel-open-smoke`
- Passed: `python3 .agents/scripts/workflow.py panel-layout-smoke`
- Passed: `git diff --check`

## Residual Risks

- macOS can still sleep for lid close, explicit Apple menu sleep, low battery, or other system-controlled reasons.
- Display awake behavior can drain battery, so it remains opt-in.
