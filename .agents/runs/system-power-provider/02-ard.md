# Detailed ARD: System Power Provider

## Architecture Summary

Implement a small `SystemPowerProvider` beside the existing memory provider. The reader layer talks to public IOKit power source APIs, while the mapping layer converts optional raw readings into deterministic UI-ready status. `SpillBarView` reads the provider for footer display and keeps provider state compact.

## Decisions

### D1: Use public IOKit power source APIs

Decision: Use `IOPSCopyPowerSourcesInfo`, `IOPSCopyPowerSourcesList`, `IOPSGetPowerSourceDescription`, and `IOPSGetProvidingPowerSourceType`.

Rationale: These APIs expose battery and external-power state without Accessibility, Screen Recording, private frameworks, or menu bar hacks.

Alternatives considered: Shelling out to `pmset` was rejected because parsing command output is slower and less structured. Private frameworks were rejected by project policy.

### D2: Keep the UI footer-sized

Decision: Show power state as one compact footer item, not as another large status meter.

Rationale: The user wants useful state without a large dashboard. Footer placement matches the existing compact Stitch mapping.

Alternatives considered: A third status meter was rejected for now because memory and actions already occupy the status section.

## Modules Affected

- `Sources/Spill/Providers/SystemPowerProvider.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Tests/SpillTests/SystemPowerProviderTests.swift`
- `.agents/design/stitch.md`

## New Types / APIs

```swift
struct SystemPowerReading {
    let currentCapacity: Int?
    let maxCapacity: Int?
    let isCharging: Bool
    let isACPowered: Bool
    let hasBattery: Bool
}

struct SystemPowerStatus {
    let value: String
    let subtitle: String?
    let chargeRatio: Double
    let state: SpillStatusState
    let symbolName: String
}

struct SystemPowerProvider: SpillStatusProvider {
    static func status(from reading: SystemPowerReading?) -> SystemPowerStatus
}
```

## Data Flow

```text
IOKit power snapshot -> SystemPowerReading -> SystemPowerStatus -> SpillStatusItem -> SpillBarView footer
```

## Permissions

- Accessibility: not required.
- Screen Recording: not required.
- Network: not required.
- File system: not required.

## Failure Modes

- IOKit returns no snapshot: display `N/A`.
- IOKit returns no battery on desktop Mac: display `AC` if external power is known.
- Capacity values are missing or invalid: display `N/A`.
- Capacity exceeds max: clamp display ratio to 100%.

## Performance Notes

- The provider does not start timers or background polling.
- The current panel reads the status during SwiftUI body evaluation. This is acceptable for the MVP because the API call is cheap and the panel is small.

## Test Strategy

### Automated

- Unit tests for normal battery, low battery, charging battery, external power without battery, unavailable input, invalid capacity, clamping, and status item conversion.

### Manual

- Launch the app, open the panel, and confirm the footer shows a compact power value.
- On battery hardware, confirm charging/on-battery states are plausible.
- On desktop hardware, confirm no fake battery percentage is shown.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Provider | Builder | `Sources/Spill/Providers/SystemPowerProvider.swift`, `Tests/SpillTests/SystemPowerProviderTests.swift` | Yes |
| UI | Builder | `Sources/Spill/Panel/SpillBarView.swift`, `.agents/design/stitch.md` | Yes after provider API sketch |
| Verification | Verifier | no production writes | Yes after implementation |

## Risks

- IOKit dictionary bridging can vary across macOS releases; the provider must treat missing keys as unavailable.
- SF Symbols may render differently by OS version; use common symbols only.
