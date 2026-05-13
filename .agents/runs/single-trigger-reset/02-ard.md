# ARD: Single Trigger Reset

## Architecture Summary

`StatusItemController` should own one fixed-width `NSStatusItem` and no spacer item. Notch geometry remains available for panel positioning and notch-candidate detection, but not for status item reservation.

## Decisions

### D1: Single Status Item

Decision:

Create only one `NSStatusItem` in `StatusItemController`.

Rationale:

macOS owns status item layout and can hide oversized items. A hidden spacer makes the entry point unreliable.

Alternatives considered:

- Oversized spacer item: rejected because it is fragile on recent macOS versions.
- Private API manipulation: rejected for trust, maintenance, and distribution reasons.

### D2: Keep Notch Geometry For Detection And Panel Layout

Decision:

Keep `MenuBarNotchGeometry.notchFrame` and `expandedNotchFrame`, but remove status item reserve length.

Rationale:

The panel and scanner may still need notch geometry. Only the status item spacer behavior is removed.

## Modules Affected

- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/MenuBar/MenuBarNotchGeometry.swift`

## New Types / APIs

None.

## Data Flow

```text
status item click -> StatusItemController -> toggleAction/showMenu
```

## Permissions

- Accessibility: not required for the trigger.
- Screen Recording: not required.
- Network: not required.
- File system: not required.

## Failure Modes

- macOS may still hide any status item when menu bar space is constrained. Spill should not claim to prevent that.
- User may move the status item manually with Command-drag.

## Performance Notes

No spacer refresh means less work during status item refresh.

## Test Strategy

### Automated

- `swift build`
- `python3 .agents/scripts/workflow.py code-gates`
- `python3 .agents/scripts/workflow.py docs`
- `python3 .agents/scripts/workflow.py run-gates`
- `python3 .agents/scripts/workflow.py language-gates`

### Manual

- Launch the app.
- Confirm one Spill menu bar icon appears.
- Click to toggle the panel.
- Right-click or Control-click to open the menu.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Remove spacer code | Builder | `StatusItemController.swift`, `MenuBarNotchGeometry.swift` | No |
| Verify gates | Verifier | workflow outputs | After builder |

## Risks

- Existing users with a saved status item location may see the trigger reset if the autosave name changes.
- The single item can still be hidden by macOS if menu bar space is exhausted.
