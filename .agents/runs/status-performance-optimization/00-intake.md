# Feature Intake

## Feature ID

`status-performance-optimization`

## Request

The maintainer reported that Spill feels slow and asked to start optimization work. A quick sample of the running app showed UI rendering and image decoding work, especially ImageIO PNG decoding, CoreGraphics image preparation, and SwiftUI layout calculation. The first slice should reduce repeated icon decoding, avoid CPU refresh sleeps on the main actor path, and cut unnecessary menu bar status view rebuilds.

## User Problem

Spill is meant to be a compact tray that opens and updates quickly. Repeated image decoding, 0.5 second CPU sampling sleeps, and full menu bar status view rebuilds can make the app feel heavier than the product direction allows.

## Necessity Assessment

- Necessary for current direction: yes, compact tray responsiveness is core acceptance.
- Better solved by Spill: yes, this is internal app overhead.
- Small enough: yes, this is an implementation slice with no new UI surface.
- Private API or permission impact: none.
- If not built: status polling and panel rendering can continue to feel sluggish and memory-heavy.

Decision: `build`

Reason: Performance is part of the existing acceptance criteria for the compact panel and status strip.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none.
- researchable: exact runtime hot spots; sampled locally with `sample`.
- assumable: keep visible UI behavior unchanged; optimize implementation internals first.
- out-of-scope: large dashboard redesign, new monitoring features, private APIs.

Resolved inputs:

- maintainer: start optimization work.
- repo-research: image data is encoded as PNG and decoded back into `NSImage`; CPU status takes two samples with a 0.5s sleep; menu bar status refresh recreates hosted chip views every refresh.
- assumption: first slice should target low-risk internal changes with focused tests.

## PRD Authoring Gate

No blocking unknowns remain. The work changes implementation performance only and preserves user-visible behavior.

## Clarifying Questions

Questions: none.

## Target User

Users who rely on Spill as a quick menu bar control tray and expect panel/status updates to feel immediate.

## Proposed Product Shape

No visible UX change. The panel and menu bar status should render the same content with less repeated decoding, less refresh delay, and fewer view rebuilds.

## Constraints

- macOS/public API constraints: use AppKit, SwiftUI, Mach, Foundation, and public APIs only.
- permission constraints: no new permissions.
- distribution constraints: no private frameworks or fragile hooks.
- performance constraints: keep polling conservative; avoid blocking the main actor for status sampling; cache decoded icons with bounded memory.

## Non-goals

- Redesign the panel.
- Add new controls or settings.
- Replace SwiftUI/AppKit composition.
- Change scan completeness or AX behavior.

## Open Questions

- Later slices can add detailed instrumentation if user-visible slowness remains.

## Decision

Status: `accepted`

Reason: The optimization targets measured and repo-observed hot spots without changing product scope.
