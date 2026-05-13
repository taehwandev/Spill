# Feature Intake

## Feature ID

`source-folder-layout`

## Request

Reorganize the Swift source files into clear feature folders before applying larger product changes. The current `Sources/Spill` directory has app lifecycle, Accessibility, menu bar scanning, panel UI, preferences, and settings files in one flat list. This makes reviews harder and makes future parallel work riskier.

## User Problem

The codebase is difficult to scan because unrelated responsibilities are mixed in one folder. Contributors need folder boundaries that match product and architecture boundaries.

## Necessity Assessment

- Necessary for current product direction: yes. The planned work will touch status item behavior, panel UI, providers, preferences, and AX features.
- Better solved by Spill, macOS, or an existing dedicated app: Spill must solve this internally as repository structure.
- Small enough for the compact tray: yes. This is a non-behavioral source layout change.
- Private API, fragile behavior, or distribution risk: no. This does not change runtime behavior.
- Cost of not building it: future changes remain harder to review and harder to split between agents.

Decision: `build`

Reason: Folder boundaries are needed before feature work can be applied one slice at a time.

## Clarifying Questions

Questions:

- None. The requested direction is clear, and the change is non-behavioral.

## Target User

Maintainers and agent workers implementing Spill features.

## Proposed Product Shape

No user-facing behavior change. Source files should be grouped by responsibility under `Sources/Spill`.

## Constraints

- macOS/public API constraints: none.
- permission constraints: none.
- distribution constraints: SwiftPM must continue to build the executable target.
- performance constraints: none.

## Non-goals

- Do not refactor implementation logic.
- Do not rename types.
- Do not remove spacer behavior in this slice.
- Do not change UI.

## Open Questions

- None.

## Decision

Status: `accepted`

Reason: The change is low-risk and directly supports the next implementation slices.
