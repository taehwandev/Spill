# Detailed ARD: Status Trigger Hit Target

## Architecture Summary

Keep status item routing local to `StatusItemController` and
`MenuBarStatusContentView`. The status item now prepends a plain trigger segment
when rendering status chips, so hit testing can distinguish panel toggle from
status-specific actions.

## Decisions

### D1: Trigger as a Status Segment

Decision:

Represent the leading Spill droplet as `MenuBarStatusSegment.Kind.trigger` when
status chips are rendered.

Rationale:

The existing status content view already knows how to size and hit-test chip
regions. Adding the trigger to the same model keeps layout deterministic without
adding a second status item or private menu bar behavior.

Alternatives considered:

- Separate `NSStatusItem`: violates the single-trigger direction and can crowd
  the menu bar.
- Remove Caffeine click behavior: contradicts the existing direct-toggle
  workflow.

### D2: Caffeine-Only Special Action

Decision:

Only Caffeine chip clicks are intercepted for direct action. Trigger and other
status chip clicks use the normal panel toggle path.

Rationale:

Caffeine is an explicit action chip. CPU and Memory are glance chips and should
not block panel access.

## Modules Affected

- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Tests/SpillTests/MenuBarStatusContentViewTests.swift`

## New Types / APIs

```swift
enum MenuBarStatusSegment.Kind {
    case trigger
    case cpu
    case memory
    case caffeine
    case sleepGuard
}
```

## Data Flow

```text
settings/status stores -> StatusItemController -> [trigger + status segments]
-> MenuBarStatusContentView -> hit-tested segment kind -> panel or Caffeine action
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: unchanged.
- Network: unchanged.
- File system: unchanged.

## Failure Modes

- Caffeine-only status item: still has a separate trigger chip.
- Hit outside known chips: falls back to panel toggle through existing action
  routing.

## Performance Notes

- Adds one small chip to status item layout when status content is visible.
- No timers, polling, or system calls.

## Test Strategy

### Automated

- `swift test --filter MenuBarStatusContentViewTests`
- `swift test`
- `swift build`
- `./scripts/build-app.sh`
- smoke scripts
- workflow verify

### Manual

- Restart the app.
- Click the leading Spill droplet and confirm the panel opens.
- Click Caffeine and confirm it toggles Caffeine.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Trigger segment | builder | `MenuBarStatusSummary.swift`, `StatusItemController.swift`, `MenuBarStatusContentView.swift` | no |
| Hit-test coverage | builder | `MenuBarStatusContentViewTests.swift` | no |
| Verification | verifier | build and smoke commands | no |

## Risks

- Users may still click the Caffeine chip expecting panel open. The leading
  droplet makes the panel trigger explicit while preserving the prior Caffeine
  quick action.
