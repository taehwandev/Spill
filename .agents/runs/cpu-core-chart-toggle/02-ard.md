# Detailed ARD: CPU Core Chart Toggle

## Architecture Summary

Extend the existing CPU provider and status store rather than adding a new provider. `SystemCPUProvider` will keep aggregate CPU status as the primary model while adding optional logical-core ratios. `SystemStatusStore` will maintain bounded per-core history for the panel CPU core bars, and `SpillSettings` will persist a Preferences toggle that controls whether `SpillBarView` uses core bars or the aggregate sparkline.

## Decisions

### D1: Keep aggregate CPU as the primary status

Decision: Preserve aggregate CPU value, subtitle, state, and history as the canonical CPU status.

Rationale: The compact row should remain glanceable and existing menu bar/status behavior depends on aggregate CPU usage.

Alternatives considered: Replace CPU status with a list of core statuses. Rejected because it would expand the compact tray toward a dashboard.

### D2: Add optional logical-core readings to the existing CPU reading

Decision: Extend `SystemCPUReading` with logical-core tick readings and extend `SystemCPUStatus` with per-core usage ratios.

Rationale: The aggregate and core readings share the same sample lifecycle, and the status store already owns history.

Alternatives considered: Add a separate CPU core provider. Rejected because the data is the same domain and would duplicate refresh coordination.

### D3: Use core bars in the existing chart slot

Decision: When enabled, replace the CPU sparkline with a 96x28 bar chart where each vertical bar is the latest usage for one logical core.

Rationale: This exposes all cores without increasing row height or adding text clutter, and it reads current per-core load more directly than a compact time heatmap.

Alternatives considered: Render one tiny line per core or a core/sample heatmap. Rejected because many cores would be visually noisy and the maintainer wanted the current per-core state to be easier to read.

### D4: Fix misleading zero display at the formatter boundary

Decision: CPU sampling displays `Sampling`; menu bar sampling displays `--`; tiny non-zero percentages display less-than text.

Rationale: `0%` should mean true measured zero, not "not sampled yet" or rounded-away activity.

Alternatives considered: Keep `0.0%` during sampling. Rejected because the maintainer flagged the ambiguity.

## Modules Affected

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

## New Types / APIs

```swift
struct SystemCPUCoreReading: Hashable, Sendable

struct SystemCPUReading {
    let coreReadings: [SystemCPUCoreReading]
}

struct SystemCPUStatus {
    let coreUsageRatios: [Double]
    let peakCoreUsageRatio: Double
    let coreCount: Int
}

final class SpillSettings {
    @Published var showsCPUCoreChart: Bool
}
```

## Data Flow

```text
host_processor_info core ticks
  -> SystemCPUProvider per-core ratios
  -> SystemStatusStore cpuCoreHistory
  -> SpillBarView CPUCoreBarChartView
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: unchanged.
- Network: unchanged.
- File system: unchanged.

## Failure Modes

- Core tick API fails: aggregate CPU still works and the row uses aggregate sparkline.
- Core count changes: core history resets to the new core count.
- CPU sampling is incomplete: value shows sampling state, and history is not appended.
- CPU unavailable: value shows unavailable and history is not appended.

## Performance Notes

Per-core samples are read only on the existing CPU refresh path. Core history is capped to the existing chart length. The bar chart draws one bounded vertical bar per logical core.

## Test Strategy

### Automated

- Update CPU provider tests for per-core ratio computation and zero formatting.
- Update status store tests for core history append/reset behavior.
- Update settings tests for default and persistence.
- Update menu bar summary tests for sampling and tiny non-zero formatting.
- Run focused tests and full Swift test suite.

### Manual

- Build and launch the app.
- Toggle CPU core bars in Preferences.
- Confirm the CPU row remains compact and does not overlap text.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| T1 CPU model/provider | Builder | `Sources/Spill/Providers/SystemCPUProvider.swift`, `Tests/SpillTests/SystemCPUProviderTests.swift` | No |
| T2 settings/preferences | Builder | `Sources/Spill/Settings/SpillSettings.swift`, `Sources/Spill/Preferences/StatusModulesPreferencesSection.swift`, `Tests/SpillTests/SpillSettingsTests.swift` | After T1 |
| T3 store/panel chart | Builder | `Sources/Spill/Providers/SystemStatusStore.swift`, `Sources/Spill/Panel/SpillBarView.swift`, `Sources/Spill/Panel/SpillStatusDetailModels.swift`, `Tests/SpillTests/SystemStatusStoreTests.swift` | After T1/T2 |
| T4 formatting/menu bar/tests | Builder | `Sources/Spill/MenuBar/MenuBarStatusDisplayOptions.swift`, `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`, `Tests/SpillTests/MenuBarStatusSummaryTests.swift` | After T1 |
| T5 verification | Verifier | `.agents/runs/cpu-core-chart-toggle/05-verification.md`, `.agents/runs/cpu-core-chart-toggle/06-closeout.md` | After T1-T4 |

## Risks

- Very high logical core counts can make each bar thin, but the visualization still preserves the "all cores" signal.
- Existing user edits in panel window-action files must not be reverted while touching `SpillBarView`.
