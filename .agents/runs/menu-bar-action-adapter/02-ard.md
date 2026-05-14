# Detailed ARD: Menu Bar Action Adapter

## Architecture Summary

The adapter is a pure mapping layer from `MenuBarItemSnapshot` to `SpillAction`. It does not own scanner state, start scans, or perform Accessibility actions. `SpillBarView` uses the adapter for display metadata and still calls `AXMenuBarItemScanner.pressItem(withID:)` with the recovered source snapshot ID.

## Decisions

### D1: Add a Pure Adapter Instead of a Provider Class

Decision:

Implement `MenuBarActionAdapter` as a pure enum with static mapping functions.

Rationale:

The existing scanner is `@MainActor` and already owns execution references. A pure adapter avoids actor isolation churn and keeps this slice focused on model mapping.

Alternatives considered:

- Add a `SpillActionProvider` conforming scanner wrapper. Deferred because protocol isolation and execution routing should be decided with a provider registry.
- Keep rendering snapshots directly. Rejected because it delays the provider architecture transition.

### D2: Encode Source Snapshot ID in Action ID

Decision:

Use `menu-bar:` as the action ID prefix and append the source snapshot ID.

Rationale:

The scanner executes by snapshot ID. Encoding the source ID keeps execution unchanged while still giving actions provider-specific namespacing.

Alternatives considered:

- Use only `stableKey` as action ID. Rejected because scanner execution requires the live snapshot ID.
- Store execution closures in `SpillAction`. Rejected because the provider model must remain a plain value.

### D3: Keep UI Behavior Stable

Decision:

Change the action tile to render from `SpillAction` metadata, but keep click execution through the existing scanner.

Rationale:

This proves the model path without changing the user's interaction model.

Alternatives considered:

- Route clicks through a new handler. Deferred until provider registry work.

## Modules Affected

- `Sources/Spill/Providers/SpillActionModels.swift`
- `Sources/Spill/Providers/MenuBarActionAdapter.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Tests/SpillTests/MenuBarActionAdapterTests.swift`
- `.agents/runs/menu-bar-action-adapter/`

## New Types / APIs

- `MenuBarActionAdapter.actions(from:)`
- `MenuBarActionAdapter.action(from:)`
- `MenuBarActionAdapter.sourceSnapshotID(for:)`
- `SpillActionState.isEnabled`
- `SpillActionState.disabledReason`

## Data Flow

```text
AXMenuBarItemScanner.items
  -> SpillDisplayMode filters MenuBarItemSnapshot values
  -> MenuBarActionAdapter maps snapshots to SpillAction values
  -> SpillBarView renders action metadata
  -> scanner.pressItem(withID:) executes the recovered source snapshot ID
```

## Permissions

- Accessibility: unchanged existing scanner behavior.
- Screen Recording: not used.
- Network: not used.
- File system: not used.

## Failure Modes

- Action lacks menu bar prefix: source ID recovery returns nil.
- Snapshot cannot be pressed: action state is disabled.
- Scanner no longer has the source snapshot ID: existing scanner failure message is used.
- Accessibility denied: panel permission state still blocks action rendering.

## Performance Notes

- Mapping is an array map over displayed items.
- No new timers, polling loops, or background tasks are added.
- Icon data remains the existing snapshot data.

## Test Strategy

### Automated

- `swift build`
- `swift test`
- Adapter unit tests for enabled mapping, disabled mapping, and source ID recovery.
- Workflow gates.
- Runtime smoke.

### Manual

- Open the panel and confirm action tiles still click the same menu bar items.
- Confirm disabled actions are dimmed if a non-pressable snapshot is present.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Run documentation | Product | `.agents/runs/menu-bar-action-adapter/` | Yes |
| Adapter and model helpers | Builder | `Sources/Spill/Providers/SpillActionModels.swift`, `Sources/Spill/Providers/MenuBarActionAdapter.swift` | Yes after scope is fixed |
| Panel integration | Builder | `Sources/Spill/Panel/SpillBarView.swift` | Yes after adapter API is stable |
| Tests and verification | Verifier | `Tests/SpillTests/MenuBarActionAdapterTests.swift`, run closeout docs | After implementation |

## Risks

- Future providers may need a richer execution registry.
- Action ID format may need migration if scanner IDs change substantially.
- Manual visual verification is still required for pixel-level UI assurance.
