# Closeout: CPU Core Chart Toggle

## Shipped

- Added a persisted Preferences toggle for CPU core chart mode.
- Extended CPU sampling to include logical-core tick deltas from public Mach host APIs.
- Added bounded per-core CPU history in `SystemStatusStore`.
- Added compact CPU core bars that replace the aggregate sparkline only when enabled and core data exists.
- Cleared CPU core history when per-core samples disappear so the panel falls back to aggregate sparkline instead of showing stale bars.
- Kept aggregate CPU value as the primary CPU status text.
- Changed CPU sampling display from measured `0%` to `Sampling` in the panel and `--` in the menu bar summary.
- Changed tiny non-zero CPU percentages to less-than formatting.

## Changed Files

- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillStatusDetailModels.swift`
- `Sources/Spill/MenuBar/MenuBarStatusDisplayOptions.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/Preferences/StatusModulesPreferencesSection.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Tests/SpillTests/SystemCPUProviderTests.swift`
- `Tests/SpillTests/SystemStatusStoreTests.swift`
- `Tests/SpillTests/MenuBarStatusSummaryTests.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`
- `.agents/runs/cpu-core-chart-toggle/*`

## Verification

- `swift test --filter SystemCPUProviderTests`
- `swift test --filter SpillSettingsTests`
- `swift test --filter SystemStatusStoreTests`
- `swift test --filter MenuBarStatusSummaryTests`
- `swift test`
- `./scripts/build-app.sh`
- `./scripts/verify-panel-layout-smoke.sh`
- `python3 .agents/scripts/workflow.py verify`
- `git diff --check`

## Residual Risks

- Very high logical-core counts can make bars thin, but all cores remain represented.
- Per-core API failure falls back to aggregate CPU chart instead of surfacing a separate error.
- Existing unrelated panel window-action layout edits were left intact.

## Follow-up Tasks

- Later slices can decide whether CPU detail popover needs a larger per-core chart.

## Docs Updated

- [x] PRD
- [x] ARD
- [ ] roadmap
- [ ] README
