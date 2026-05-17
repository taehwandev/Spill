# Detailed ARD: Panel Feature Store

## Architecture Summary

Add a narrow panel feature-store layer that computes presentation state for the
existing Spill panel. The store derives the same values that `SpillBarView`
previously computed, publishes a single rendering state, and handles panel
events that affect pinning, action feedback, and status-detail target state.

## Decisions

### D1: Add `PanelStore` as the panel feature owner

Decision:

Create a `@MainActor ObservableObject` store that owns derived panel
presentation state and exposes `send(_:)` for feature events.

Rationale:

This follows ARD-008 without forcing a global reducer. It reduces SwiftUI view
responsibility while preserving current behavior.

Alternatives considered:

- Keep derivation in `SpillBarView`: rejected because it continues the current
  coupling.
- Adopt TCA/Redux now: rejected as too much ceremony for this app size.

### D2: Move panel user events into typed actions

Decision:

Move pinning, menu bar action feedback, window action feedback, and
status-detail target changes behind `PanelAction` cases. Keep AppKit panel
hosting callbacks, such as close and settings presentation, in the bridge
controller layer.

Rationale:

These events are part of panel feature state and can be tested without changing
user-facing behavior. AppKit presentation remains outside the store because it
belongs to bridge controllers.

Alternatives considered:

- Move all AppKit callbacks into the store now: rejected because it would couple
  feature state to panel/window ownership.

### D3: Preserve existing `SpillPanelState`

Decision:

Keep the current readiness enum and include it inside the new rendering state
instead of renaming it immediately.

Rationale:

The enum already captures permission, scanning, empty, and ready states. Keeping
it avoids unnecessary churn.

Alternatives considered:

- Rename to `PanelReadinessState`: deferred until a larger naming cleanup.

## Modules Affected

- `Sources/Spill/Panel`
- `Tests/SpillTests`
- `.agents/runs/panel-feature-store`

## New Types / APIs

```swift
@MainActor
final class PanelStore: ObservableObject {
    @Published private(set) var state: PanelState
    func send(_ action: PanelAction)
}

struct PanelState: Equatable {
    let displayItems: [MenuBarItemSnapshot]
    let pinnedItems: [MenuBarItemSnapshot]
    let displayActionItems: [MenuBarItemSnapshot]
    let actionItems: [SpillDisplayedActionItem]
    let visibleStatusModules: [SpillStatusModule]
    let readiness: SpillPanelState
    let actionFeedback: SpillActionFeedback?
    let statusDetailTarget: SpillStatusDetailTarget?
}

enum PanelAction {
    case refreshDerivedState
    case setStatusDetailTarget(SpillStatusDetailTarget?)
    case togglePinned(MenuBarItemSnapshot)
    case performMenuBarAction(SpillDisplayedActionItem)
    case performWindowAction(SpillAction)
}
```

## Data Flow

```text
SpillSettings / AXMenuBarItemScanner / Accessibility / action performers
  -> PanelStore
  -> PanelState
  -> SpillBarView sends typed PanelAction events
```

## Permissions

- Accessibility: read only as existing state input; no new permission prompts.
- Screen Recording: unchanged and not required.
- Network: unchanged.
- File system: unchanged.

## Failure Modes

- Accessibility missing: derived state must produce permission-required
  readiness.
- Scanner is active with no display items: derived state must produce scanning
  readiness.
- Scanner is inactive with no display items: derived state must produce empty
  readiness.
- Store subscription misses a change: tests and runtime smoke should catch stale
  rendering inputs.

## Performance Notes

Derived state is synchronous and based on existing in-memory settings/scanner
data. No new timers, polling loops, or AX reads are introduced.

## Test Strategy

### Automated

- Unit tests for panel state derivation and typed panel actions.
- Existing `swift test`.
- Existing build and workflow gates.

### Manual

- Runtime smoke launch.
- Panel open smoke.
- Panel layout smoke.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Add store/state/action | Builder | `Sources/Spill/Panel/PanelStore.swift` | No |
| Wire panel view/controller | Builder | `SpillBarView.swift`, `SpillPanelController.swift` | No |
| Add tests | Builder | `Tests/SpillTests/PanelStoreTests.swift` | Yes after store API exists |
| Verify | Verifier | no source write scope | Yes after implementation |

## Risks

- Accidentally changing panel rendering order.
- Missing a Combine subscription and leaving panel state stale.
- Adding too much architecture in one slice.
