# Closeout: Menu Bar Status Background Cleanup

## Shipped

- Removed rounded colored backgrounds from the menu bar status chips.
- Normal status icons now use the native label tone, while active and warning states retain state color.
- Added focused test coverage for transparent status chip rendering.

## Changed Files

- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Tests/SpillTests/MenuBarStatusContentViewTests.swift`
- `.agents/runs/menu-bar-status-background-cleanup/*`

## Verification

- `swift test`
- `swift build`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py status-click-smoke`
- `python3 .agents/scripts/workflow.py code-gates`
- `git diff --check`

## Residual Risks

- Interactive visual confirmation still requires looking at the physical macOS menu bar.

## Follow-up Tasks

- None planned.

## Docs Updated

- [x] PRD
- [x] ARD
- [ ] roadmap
- [ ] README
