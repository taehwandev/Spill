# Detailed ARD: Provider Refresh Store

## Architecture Summary

Introduce a `SystemStatusStore` observable object in the provider layer. The store keeps cached memory and power status values and exposes a synchronous `refresh()` method backed by injectable reader closures. `SpillPanelController` owns one store for the panel lifecycle and refreshes it before showing the panel. `SpillBarView` observes the store instead of reading providers directly.

## Decisions

### D1: Use a small observable store before a full registry

Decision: Add `SystemStatusStore` for current system statuses rather than a generic provider registry.

Rationale: The app currently has only memory and power providers. A concrete store solves the immediate direct-read problem without adding premature generic complexity.

Alternatives considered: A full async registry was deferred until CPU, network, AI, or window providers need shared behavior.

### D2: Use injectable sync readers

Decision: Store refresh accepts closures returning `SystemMemoryStatus` and `SystemPowerStatus`.

Rationale: Existing providers are synchronous and cheap. Closure injection makes tests deterministic without mocking AppKit or IOKit.

Alternatives considered: Async provider protocol fan-out was deferred because the current providers do not need it yet.

## Modules Affected

- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Tests/SpillTests/SystemStatusStoreTests.swift`

## New Types / APIs

```swift
@MainActor
final class SystemStatusStore: ObservableObject {
    @Published private(set) var memory: SystemMemoryStatus
    @Published private(set) var power: SystemPowerStatus

    func refresh()
}
```

## Data Flow

```text
System providers -> SystemStatusStore.refresh() -> cached statuses -> SpillBarView
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: not required.
- Network: not required.
- File system: not required.

## Failure Modes

- Provider read returns unavailable: store publishes unavailable status.
- Panel appears before refresh: default unavailable state renders safely.
- Future expensive provider is added without store integration: code review should reject direct view reads.

## Performance Notes

- No timer is introduced.
- Refresh runs once before panel presentation and once when the SwiftUI view appears.
- Future visible refresh cadence should be explicit and cancellable.

## Test Strategy

### Automated

- Unit tests for default unavailable state.
- Unit tests for injected refresh values.
- Unit tests for repeated refresh updating cached values.

### Manual

- Open the panel and confirm memory and power still render.
- Confirm runtime and panel-open smoke tests still pass.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Store | Builder | `Sources/Spill/Providers/SystemStatusStore.swift`, `Tests/SpillTests/SystemStatusStoreTests.swift` | Yes |
| UI wiring | Builder | `Sources/Spill/Panel/SpillBarView.swift`, `Sources/Spill/Panel/SpillPanelController.swift` | Yes after store API sketch |
| Verification | Verifier | run docs only | Yes after implementation |

## Risks

- Refresh-on-appear may duplicate the pre-show refresh; this is acceptable until a visible refresh lifecycle is added.
- A concrete store may need replacement by a generic provider registry later.
