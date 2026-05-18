# Detailed ARD: Menu Bar Status Background Cleanup

## Architecture Summary

Keep the existing single `NSStatusItem` and AppKit-rendered menu bar status content. The change is limited to `MenuBarMetricChipView` styling: remove the layer-backed rounded background and use native label-color icon rendering for normal state. No provider, settings, panel, permission, or lifecycle architecture changes are required.

## Decisions

### D1: Remove Layer-Backed Chip Backgrounds

Decision:

Do not create a layer or assign a background color for each menu bar status chip.

Rationale:

The layer background is the source of the visible rounded colored pills. Removing it gives a cleaner native menu bar presentation without changing layout or click routing.

Alternatives considered:

- Lower the background alpha: still leaves visible containers next to the clock.
- Add a preference: unnecessary for a narrow visual correction.

### D2: Keep Existing Segment Geometry

Decision:

Preserve segment widths, spacing, and hit-testing math.

Rationale:

This avoids regressions in the Caffeine click target and panel trigger behavior.

Alternatives considered:

- Repack the segments more tightly: higher risk for click-target and truncation regressions.

## Modules Affected

- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Tests/SpillTests/MenuBarStatusContentViewTests.swift`
- `.agents/runs/menu-bar-status-background-cleanup/*`

## New Types / APIs

```swift
// No new public types or APIs.
```

## Data Flow

```text
SystemStatusStore -> MenuBarStatusSummary -> StatusItemController -> MenuBarStatusContentView -> transparent chip views
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: not used.
- Network: unchanged.
- File system: unchanged.

## Failure Modes

- If a status provider is unavailable, existing unavailable text and icon state still render.
- If a custom trigger icon is selected, it uses the same renderer with the updated normal tint.

## Performance Notes

Removing layer-backed backgrounds should not add work. Existing trigger animation behavior remains unchanged.

## Test Strategy

### Automated

- Run `swift test`.
- Run `swift build`.
- Keep existing segment ordering and hit-testing tests.
- Add a focused assertion that status chip views do not draw layer backgrounds.

### Manual

- Launch the app.
- Confirm the menu bar status item appears without rounded colored chip backgrounds.
- Open and close the panel from the status item.
- Toggle Caffeine from its segment when visible.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Remove menu bar status chip backgrounds | builder | `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`, `Tests/SpillTests/MenuBarStatusContentViewTests.swift` | No |
| Verify and close out | verifier | `.agents/runs/menu-bar-status-background-cleanup/05-verification.md`, `.agents/runs/menu-bar-status-background-cleanup/06-closeout.md` | No |

## Risks

- Visual confirmation still requires launching the macOS app because unit tests cannot inspect the real menu bar.
- Changing normal icon tint to label color may make the trigger quieter than before, which is intentional for this cleanup.
