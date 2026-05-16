# Closeout: Panel Visibility Polish

## Shipped

- Menu bar status chips now show module icons and default to one-decimal percentage precision.
- CPU startup sampling now shows `0.0%` with a sampling label instead of an unavailable placeholder.
- CPU disabled state remains explicitly unavailable.
- The panel is wider and taller, with more visible status detail rows and larger action controls.
- Settings and Quit actions are visible in the panel header.

## Changed Files

- `.agents/runs/panel-visibility-polish/00-intake.md`
- `.agents/runs/panel-visibility-polish/01-prd.md`
- `.agents/runs/panel-visibility-polish/02-ard.md`
- `.agents/runs/panel-visibility-polish/03-task-breakdown.yml`
- `.agents/runs/panel-visibility-polish/04-agent-briefs.md`
- `.agents/runs/panel-visibility-polish/05-verification.md`
- `.agents/runs/panel-visibility-polish/06-closeout.md`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/Panel/SpillActionViews.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Panel/SpillPanelMetrics.swift`
- `Sources/Spill/Panel/SpillStatusDetailModels.swift`
- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Sources/Spill/Providers/SystemMemoryProvider.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Tests/SpillTests/SpillPanelLayoutTests.swift`
- `Tests/SpillTests/SystemStatusStoreTests.swift`

## Verification

- `swift test` passed.
- `python3 .agents/scripts/workflow.py panel-layout-smoke` passed.
- `python3 .agents/scripts/workflow.py verify` passed after run docs were completed.

## Residual Risks

- CPU and memory values may still differ from third-party utilities when they use different sampling windows or memory formulas.
- This run did not add storage throughput, network throughput, or Activity Monitor parity providers.

## Follow-up Tasks

- Add an explicit metric-source tooltip or details copy if users need to compare Spill values against Activity Monitor or third-party monitor apps.
- Consider a future provider slice for storage, network throughput, and memory pressure if parity with the referenced utility is required.

## Docs Updated

- [x] PRD
- [x] ARD
- [ ] roadmap
- [ ] README
