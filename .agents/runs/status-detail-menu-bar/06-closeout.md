# Closeout: Status Detail Menu Bar

## Shipped

- Added persisted menu bar visibility settings for CPU and memory.
- Added menu bar status text formatting with CPU and memory summaries.
- Show status text directly in the single macOS status item when menu bar values are enabled, and keep icon-only behavior when no menu bar values are enabled.
- Shared `SystemStatusStore` and `AIStatusStore` between the panel and status item.
- Added a refresh loop for menu bar values when at least one menu bar status value is enabled.
- Added click-to-open detail popovers for system and AI status pills.
- Expanded visible status pills into two-line instrument cells so availability, budget, and route hints are readable before opening details.
- Added CPU available/user/system/nice/idle detail.
- Added richer memory, including available/free/active/inactive/wired/compressed fields, and network status detail fields.
- Added Metal-based GPU availability, working-set budget, and device trait details.
- Added tests for menu bar summary formatting and status setting persistence.

## Files

- `Sources/Spill/MenuBar/SpillMenuBarStatusItem.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Sources/Spill/Providers/SystemMemoryProvider.swift`
- `Sources/Spill/Providers/SystemGPUProvider.swift`
- `Sources/Spill/Providers/SystemNetworkProvider.swift`
- `Tests/SpillTests/MenuBarStatusSummaryTests.swift`
- `Tests/SpillTests/SystemGPUProviderTests.swift`

## Verification

- `swift test` passed.
- `python3 .agents/scripts/workflow.py panel-layout-smoke` passed.
- `python3 .agents/scripts/workflow.py runtime-smoke` passed.
- `python3 .agents/scripts/workflow.py verify` passed.
- `git diff --check` passed.

## Residual Risk

- Menu bar width is controlled by the enabled status values. Users with crowded menu bars should disable values they do not need.
- Manual visual validation is still useful because live popover anchoring depends on the active macOS UI session.
