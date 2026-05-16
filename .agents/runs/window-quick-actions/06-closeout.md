# Closeout: Window Quick Actions

## Shipped

- Added deterministic window frame planning for left half, right half, center, maximize, next display, and restore.
- Added public Accessibility focused-window read/write support.
- Added `WindowActionStore` with permission, availability, next-display, and restore disabled states.
- Added compact window action buttons at the front of the existing ACTIONS row.
- Added best-effort previous-frame restore.
- Added frame planner unit tests.

## Files

- `Sources/Spill/Providers/WindowActionProvider.swift`
- `Sources/Spill/Accessibility/AXConstants.swift`
- `Sources/Spill/Accessibility/AXElementReader.swift`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Tests/SpillTests/WindowFramePlannerTests.swift`

## Verification

- `swift test` passed.
- `python3 .agents/scripts/workflow.py panel-layout-smoke` passed.
- `python3 .agents/scripts/workflow.py runtime-smoke` passed.
- `python3 .agents/scripts/workflow.py verify` passed.
- `git diff --check` passed.

## Residual Risk

- Some apps or special windows may reject AX position or size writes.
- Coordinate behavior should be manually validated on multi-display setups.
- Live execution requires Accessibility permission and a normal focused app window.
