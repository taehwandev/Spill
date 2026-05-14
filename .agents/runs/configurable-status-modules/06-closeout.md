# Closeout: Configurable Status Modules

## Summary

Added configurable compact status modules for CPU and memory. Preferences now exposes enable toggles and up/down ordering controls. The panel renders enabled status meters in saved order, and `SystemStatusStore` skips CPU and memory provider readers when those modules are disabled.

## Changed Files

- `Sources/Spill/Providers/SpillStatusModule.swift`
- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Preferences/StatusModulesPreferencesSection.swift`
- `Sources/Spill/Preferences/PreferencesView.swift`
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

- CPU values may appear after a short delay on panel open because CPU usage needs two samples.
- Power remains a footer status outside the configurable meter list. A later UX decision should decide whether footer modules join the same ordering model.
