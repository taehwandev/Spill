# ARD: Menu Bar Glance Summary

## Architecture Summary

Constrain the existing menu bar status pathway to a supported glance set of CPU and memory. `SpillMenuBarStatusItem` defines the supported set, `SpillSettings` ignores unsupported writes and stale persisted values, `MenuBarStatusSummary` filters its input and emits renderable segment metadata, `StatusItemController` installs a custom AppKit chip view inside the existing status button, and `SpillBarView` only exposes menu bar toggles for CPU and memory detail popovers.

## Decisions

### D1: CPU And Memory Only

Decision: Limit this slice's menu bar glance to CPU and memory.

Rationale: CPU and memory have direct percentage readings that fit the clock-area status surface. AI active detection is not reliable yet, and GPU/network values are better suited to panel detail.

Alternatives considered: Keep AI/GPU optional in the menu bar. Rejected because stale toggles and low-confidence signals recreate the crowded UI problem.

### D2: Filter Unsupported Persisted Values

Decision: Normalize enabled menu bar status settings against the supported glance set.

Rationale: Existing local defaults may contain AI, GPU, or network from earlier builds. Filtering prevents old settings from bringing back the long summary.

Alternatives considered: Only change defaults. Rejected because it would not fix existing users.

### D3: Keep Panel Detail Broad

Decision: Keep AI, GPU, and network visible in the panel and remove only their menu bar visibility controls.

Rationale: The panel has room for lower-confidence or detailed state; the menu bar does not.

Alternatives considered: Remove AI/GPU/network panel rows. Rejected because that would undo useful panel detail unrelated to the menu bar problem.

### D4: Render Chips Inside The Existing Status Item

Decision: Render CPU and memory with `MenuBarStatusContentView` inside the existing `NSStatusBarButton` instead of setting a plain title string.

Rationale: The clock-area surface should stay simple, but it still needs real UI affordance: icon, percent value, and a small usage bar that can be scanned quickly.

Alternatives considered: Keep attributed status title text. Rejected because it does not satisfy the requested visual UI treatment.

## Modules Affected

- `Sources/Spill/MenuBar/SpillMenuBarStatusItem.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`
- `Tests/SpillTests/MenuBarStatusSummaryTests.swift`

## New Types / APIs

```swift
static let glanceSupported = cpuAndMemory
struct MenuBarStatusSegment
final class MenuBarStatusContentView
```

## Data Flow

```text
SystemStatusStore -> MenuBarStatusSummary -> MenuBarStatusSegment -> StatusItemController -> MenuBarStatusContentView -> existing NSStatusItem button
```

Panel detail:

```text
SpillBarView status detail -> optional menu bar toggle for CPU or memory only
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: none.
- Network: none.
- File system: no new access.

## Failure Modes

- CPU or memory unavailable: summary renders `--`.
- Old defaults include unsupported values: normalized settings drop them.
- User opens GPU, network, or AI detail: no menu bar toggle is shown for this slice.

## Performance Notes

No new refresh source is added. The existing status refresh loop continues to drive CPU and memory.

## Test Strategy

### Automated

- Settings tests cover CPU/memory default and unsupported value normalization.
- Summary tests cover filtering out explicitly supplied unsupported values.
- Workflow gates check single status item and no spacer behavior.

### Manual

- Launch the app and confirm CPU and memory render as compact chips near the clock area.
- Open the panel and confirm AI/GPU/network remain visible in the panel.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Menu bar glance restriction | Builder | MenuBar, Settings, Panel, Tests | No |
| Menu bar visual chips | Builder | MenuBar, Tests | No |

## Risks

- Users who previously enabled AI/GPU/network in the menu bar will see those values removed from the clock-area summary.
- Future formatting preferences need a separate PRD to avoid growing this slice.
