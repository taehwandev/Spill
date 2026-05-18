# Detailed ARD: Panel Glass Footer Contrast

## Architecture Summary

Keep the existing SwiftUI footer and panel material architecture. Add a small footer contrast style model that maps semantic footer states to foreground roles. The view uses these roles to render colored status icons, readable secondary labels, and primary values over a transparent footer. Replace weak blue active accents with teal in the shared panel status style and menu bar status renderer.

## Decisions

### D1: Role-Based Foreground Contrast

Decision:

Represent footer contrast as roles instead of hard-coded per-view foreground colors.

Rationale:

The footer has repeated badge-like items. A shared role model keeps values consistently high contrast and makes the behavior testable.

Alternatives considered:

- Hard-code `.primary` in each `Text`: less clear and easier to regress.
- Reintroduce a translucent footer background: conflicts with the requested clean glass look.

### D2: No Pixel Sampling

Decision:

Use semantic SwiftUI foreground roles and subtle adaptive shadowing instead of sampling the desktop or panel backing pixels.

Rationale:

Screen sampling would add complexity, permissions risk, and performance cost. The current issue can be addressed with foreground hierarchy.

Alternatives considered:

- Pixel sampling behind the panel. Rejected as over-scoped and potentially fragile.

### D3: Teal Active Accent

Decision:

Use teal for active/refreshing status accents instead of blue in the affected glass and menu bar surfaces.

Rationale:

The maintainer observed blue accents disappearing on bright backgrounds. Teal matches the existing visible CPU/storage accent family and remains more legible over bright glass.

Alternatives considered:

- Keep blue and add a background. Rejected because the requested direction is clean transparent glass.

## Modules Affected

- `Sources/Spill/Panel/SpillFooterContrastStyle.swift`
- `Sources/Spill/Panel/SpillFooterView.swift`
- `Sources/Spill/Panel/SpillStatusStyle.swift`
- `Sources/Spill/Panel/SpillPanelState.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Tests/SpillTests/SpillFooterContrastStyleTests.swift`
- `.agents/runs/panel-glass-footer-contrast/*`

## New Types / APIs

```swift
enum SpillFooterForegroundRole
struct SpillFooterBadgeStyle
```

These are internal implementation types for the panel footer.

## Data Flow

```text
Panel state / stores -> SpillFooterView -> SpillFooterBadgeStyle -> foreground roles -> SwiftUI rendering
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: not used.
- Network: unchanged.
- File system: unchanged.

## Failure Modes

- If semantic foreground roles are still insufficient over highly mixed backgrounds, future work may need material luminance sampling.
- Removing the footer capsule could expose spacing issues; keep existing height and padding.

## Performance Notes

No new timers, polling, scanner refreshes, provider reads, or screen sampling.

## Test Strategy

### Automated

- Unit test footer contrast role mapping.
- `swift test`
- `swift build`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`
- `git diff --check`

### Manual

- Launch the app and open the panel over light and dark backgrounds.
- Confirm footer values remain readable.
- Confirm footer remains visually transparent.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Add footer contrast style model | builder | `SpillFooterContrastStyle.swift`, `SpillFooterView.swift` | No |
| Add tests and verification docs | builder | `SpillFooterContrastStyleTests.swift`, run docs | No |

## Risks

- Automated tests validate contrast role mapping, not actual perceptual contrast on a real desktop background.
