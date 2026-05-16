# Closeout: Panel Controls Refresh

## Shipped

- Documentation-first update for the expanded panel controls refresh scope.
- Live status refresh split from menu bar scanning so CPU and memory chips refresh on a one-second metric cadence.
- GPU removed from the primary panel status surface.
- Storage added as a primary CPU, Memory, and Storage panel metric row.
- Compact sparklines added for CPU, Memory, and Storage with bounded in-memory history.
- Sleep Guard default duration preference added.
- Panel footer Quit control added.
- Settings icon removal fixed by persisting hidden item keys separately from selected item keys.

## Changed Files

- `.agents/runs/panel-controls-refresh/00-intake.md`
- `.agents/runs/panel-controls-refresh/01-prd.md`
- `.agents/runs/panel-controls-refresh/02-ard.md`
- `.agents/runs/panel-controls-refresh/03-task-breakdown.yml`
- `.agents/runs/panel-controls-refresh/04-agent-briefs.md`
- `.agents/runs/panel-controls-refresh/05-verification.md`
- `.agents/runs/panel-controls-refresh/06-closeout.md`
- `.agents/tasks/roadmap.yml`
- `README.md`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Panel/DetectedItemsListView.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillFooterView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Panel/SpillStatusDetailModels.swift`
- `Sources/Spill/Panel/SpillSystemStatusPresentation.swift`
- `Sources/Spill/Preferences/PowerPreferencesSection.swift`
- `Sources/Spill/Preferences/StatusModulesPreferencesSection.swift`
- `Sources/Spill/Providers/AIStatusStore.swift`
- `Sources/Spill/Providers/SpillStatusModule.swift`
- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Sources/Spill/Providers/SystemMemoryProvider.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Providers/SystemStorageProvider.swift`
- `Sources/Spill/Settings/SpillDisplayMode.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`
- `Tests/SpillTests/SystemStatusStoreTests.swift`
- `Tests/SpillTests/SystemStorageProviderTests.swift`

## Verification

- `swift test`: passed, 100 tests.
- `python3 .agents/scripts/workflow.py panel-layout-smoke`: passed.
- `python3 .agents/scripts/workflow.py verify`: passed.
- `git diff --check`: passed.

## Residual Risks

- Storage values may differ from Finder if purgeable or system-reserved capacity is reported differently.
- Manual validation is still needed to confirm the live menu bar values visibly move over time after relaunch.
- Hidden item persistence removes items from Spill surfaces, but the detected item remains visible in Preferences so the user can add it again.

## Follow-up Tasks

- Consider a future explicit "Show hidden items" filter if hidden item lists become long.
- Consider richer storage trends later, without expanding the panel into a dashboard.

## Docs Updated

- [x] PRD
- [x] ARD
- [x] task breakdown
- [x] agent briefs
- [x] verification checklist
- [x] closeout
- [x] roadmap
- [x] README
