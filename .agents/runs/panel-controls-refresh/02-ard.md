# Detailed ARD: Panel Controls Refresh

## Architecture Summary

Keep the status model provider-based while adding a storage provider, bounded metric histories for sparklines, and a clearer panel/footer control surface. Status refresh cadence must be separate from AX scanner cadence so menu bar metric values can remain live without increasing Accessibility scan cost.

## Decisions

### D1: Split Metric Refresh From Scanner Refresh

Decision:

Use a short status-only refresh loop for CPU and memory menu bar values while leaving menu bar item scanning on the existing conservative interval.

Rationale:

The stale value problem came from sharing the scanner-oriented refresh interval with lightweight metrics.

Alternatives considered:

- Lower `settings.refreshInterval` globally. Rejected because it would also increase AX scanning.

### D2: Replace Primary GPU Status With Storage

Decision:

Remove GPU from the primary panel status rows and add Storage using public local volume capacity APIs.

Rationale:

The existing GPU value is not useful enough for the compact panel. Storage is a more common glance metric and can be collected without new permissions.

Alternatives considered:

- Keep GPU and add Storage. Rejected for this slice because the maintainer wants the panel to become clearer and likely three rows.

### D3: Use Bounded Sparklines

Decision:

Store small in-memory histories for panel metrics and render compact SwiftUI sparklines in the panel rows.

Rationale:

Graphs should show trend without becoming a dashboard or increasing persistence complexity.

Alternatives considered:

- Persist historical samples. Rejected as unnecessary for a compact tray.

### D4: Keep Sleep Guard Duration As Settings

Decision:

Persist a `SleepGuardDuration` default in `SpillSettings` and use it for panel quick start.

Rationale:

The duration enum already exists and avoids custom input validation for this slice.

Alternatives considered:

- Arbitrary custom minutes. Deferred.

### D5: Fix Settings Removal At The Source

Decision:

Trace Settings icon removal through `selectedItemKeys` and visible action derivation, then update the persistence/refresh path where it breaks.

Rationale:

The panel should render from settings state, so removal must update state and trigger dependent views.

Alternatives considered:

- Hide removed icons only in the panel view. Rejected because it would not fix persistence.

## Modules Affected

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillFooterView.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Providers/SystemStorageProvider.swift`
- `Sources/Spill/Providers/SpillStatusModule.swift`
- `Sources/Spill/Preferences/PowerPreferencesSection.swift`
- `Sources/Spill/Preferences/DetectedItemsListView.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Tests/SpillTests`

## New Types / APIs

```swift
struct SystemStorageReading: Hashable, Sendable
struct SystemStorageStatus: Hashable, Sendable
struct SystemStorageProvider: SpillStatusProvider
struct MetricHistory: Hashable
struct MetricSparklineView: View
```

## Data Flow

```text
Foundation volume capacity -> SystemStorageProvider -> SystemStatusStore -> SpillBarView row
SystemStatusStore samples -> bounded history -> MetricSparklineView
Preferences removal -> SpillSettings.selectedItemKeys -> panel action list -> status item refresh
SleepGuardDuration picker -> SpillSettings -> SpillFooterView quick action -> SleepGuardController
```

## Permissions

- Accessibility: unchanged; still needed only for menu bar scanning, action pressing, and window actions.
- Screen Recording: none.
- Network: none.
- File system: local volume capacity only through public resource values.

## Failure Modes

- Storage capacity unavailable: show `N/A` row with muted state.
- Metric history empty: sparkline renders a flat muted line or no graph area without layout shift.
- Settings removal target missing: state remains stable and refreshes visible lists.
- Sleep Guard duration raw value invalid: normalize to the default duration.

## Performance Notes

- Metric histories must be bounded.
- Status refresh must not trigger AX scanning.
- Storage capacity polling should be lightweight and run with the existing status loop.
- Panel open path should not wait for graph history, storage, AI process scanning, or AX window refresh.

## Test Strategy

### Automated

- Storage provider mapping tests.
- Settings persistence tests for Sleep Guard duration.
- Settings removal tests where possible at model level.
- Status store tests for storage refresh and history bounds.
- Existing panel layout and workflow smoke tests.

### Manual

- Launch app and observe menu bar CPU/memory changes after closing panel detail.
- Open panel and confirm three status rows with graphs.
- Change Sleep Guard duration in Preferences and start from footer.
- Remove an icon in Settings and confirm it disappears from panel.
- Quit from panel footer.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Status refresh and storage provider | builder | Providers, AppDelegate, tests | No |
| Panel rows and graphs | builder | Panel views, metrics | No |
| Sleep Guard duration and Quit | builder | Settings, Preferences, Footer | No |
| Settings removal bug | builder | Preferences, Settings, tests | No |
| Documentation and verification | builder | `.agents/runs/panel-controls-refresh` | No |

## Risks

- Adding too much footer text can crowd the compact panel.
- Graphs can make the panel feel like a dashboard if overstyled.
- Storage values can differ from Finder if macOS reports purgeable capacity differently.
