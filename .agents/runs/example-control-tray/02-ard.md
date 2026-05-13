# Detailed ARD: Example Control Tray

## Architecture Summary

The control tray should introduce a thin model layer between providers and SwiftUI views. Existing scanner state can feed pinned actions initially, while system, AI, and window sections can start with placeholder providers and become real implementations in later tasks.

## Decisions

### D1: Section Shell First

Decision:

Build the panel section shell before implementing all providers.

Rationale:

This lets UI, product shape, and model boundaries stabilize before system API work.

### D2: Existing Selection Drives Pinned Actions

Decision:

Use `selectedItemKeys` and existing scanner items as the first pinned action source.

Rationale:

Avoids introducing a new persistence model until the panel shape is validated.

## Modules Affected

- `Sources/Spill/SpillBarView.swift`
- new provider/model files under `Sources/Spill/`
- later: `SpillSettings.swift` for preferences

## New Types / APIs

```swift
struct SpillStatusItem: Identifiable, Hashable
struct SpillAction: Identifiable, Hashable
enum SpillPanelSection
```

## Data Flow

```text
provider/scanner -> plain models -> SpillBarView sections -> action executor
```

## Permissions

- Accessibility: required only for scanner/window actions.
- Screen Recording: not required.
- Network: not required.

## Failure Modes

- Accessibility missing.
- Provider unavailable.
- AX item stale.
- Window action unsupported.

## Performance Notes

Providers should cache or sample conservatively.

## Test Strategy

### Automated

- `swift build`

### Manual

- Launch app.
- Open panel.
- Check compact layout.
- Check missing permission state.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Model types | C1 | new model files | yes |
| Panel shell UI | C2 | `SpillBarView.swift` | after model sketch |
| Provider placeholders | C3 | new provider files | yes |

## Risks

- Too much UI in one view.
- Placeholder providers becoming permanent.
- Panel growing beyond compact target.
