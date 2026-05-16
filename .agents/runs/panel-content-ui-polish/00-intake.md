# Feature Intake

## Feature ID

`panel-content-ui-polish`

## Request

The maintainer wants another UI pass after the storage and graph work. They provided Stitch MCP access and clarified that the left-side settings/navigation mock is not meaningful for this pass. The implementation should use the Stitch panel content as guidance while focusing on the actual compact tray content: status, AI, window actions, menu bar actions, footer controls, settings, and quit.

## User Problem

The panel currently exposes the right data, but the visual grouping still feels rough and overly boxy. The user needs a compact surface where content hierarchy, commands, and state values are easier to scan without becoming a large dashboard.

## Necessity Assessment

- Necessary for current product direction: yes, this improves the primary product surface.
- Better solved by Spill: yes, this is first-party panel composition.
- Small enough for compact tray: yes, scope is polish and hierarchy only.
- Private APIs or new permissions: no.
- If not built: the app remains functionally improved but visually unresolved.

Decision: `build`

Reason: This is a compact panel UI refinement aligned with the PRD's "glance first" and "small surface area" principles.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none
- researchable: current SwiftUI layout, Stitch panel content structure, panel smoke constraints
- assumable: exact spacing, row sizing, and text hierarchy can follow existing SwiftUI patterns
- out-of-scope: left settings/nav mock, large dashboard layout, new external integrations

Resolved inputs:

- maintainer: ignore left-side UI and focus on content
- repo-research: the panel already has provider-backed CPU, memory, storage, AI, window, action, and footer sections
- assumption: improve hierarchy using existing components, not a full redesign

## PRD Authoring Gate

Decision is `build`, clarity is `clear`, and there are no blocking questions.

## Clarifying Questions

Questions: none

## Target User

Mac users who open Spill repeatedly during work and need the panel to answer system state and action availability quickly.

## Proposed Product Shape

The panel should keep the same compact tray surface but reduce visual noise. The header should make Settings and Quit visible without stealing the first scan. Status rows should read as a single performance stack. AI, window actions, and menu bar actions should feel like content bands instead of unrelated boxes. The footer should communicate active utility state in a concise control strip.

## Constraints

- macOS/public API constraints: no new platform APIs are required.
- permission constraints: Accessibility permission behavior stays unchanged.
- distribution constraints: no private APIs or external runtime dependencies.
- performance constraints: view changes must not increase provider refresh frequency or AX scan frequency.

## Non-goals

- Rebuilding the left-side settings mock from Stitch.
- Adding new data providers.
- Adding new app icons or generated assets.
- Turning the panel into a large monitoring dashboard.

## Open Questions

- Future exact visual theming can be refined after manual screenshots.

## Decision

Status: `accepted`

Reason: The request is clear and can be implemented as a bounded UI polish pass.
