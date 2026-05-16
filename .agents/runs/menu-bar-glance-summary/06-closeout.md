# Closeout: Menu Bar Glance Summary

## Shipped

- Limited the default macOS menu bar glance to CPU and memory.
- Replaced plain menu bar status title text with compact AppKit chips that show symbol, percentage, and usage bar.
- Added a supported menu bar glance set so stale AI, GPU, or network settings are ignored.
- Changed menu bar CPU and memory output to compact percentages.
- Removed menu bar visibility toggles from AI, GPU, and network detail popovers.
- Kept AI, GPU, and network details in the panel.

## Changed Files

- `Sources/Spill/MenuBar/SpillMenuBarStatusItem.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`
- `Tests/SpillTests/MenuBarStatusSummaryTests.swift`

## Verification

- `swift test` passed.
- `python3 .agents/scripts/workflow.py panel-layout-smoke` passed.
- `python3 .agents/scripts/workflow.py runtime-smoke` passed.
- `python3 .agents/scripts/workflow.py verify` passed.
- `git diff --check` passed.

## Residual Risks

- Manual menu bar placement is still controlled by macOS.
- Live visual confirmation is still useful because this environment cannot reliably screenshot the menu bar.

## Follow-up Tasks

- Add formatting preferences in a separate slice if needed.
- Revisit AI active detection only when reliable usage events are available.

## Docs Updated

- [x] PRD
- [x] ARD
- [x] roadmap
- [x] README
