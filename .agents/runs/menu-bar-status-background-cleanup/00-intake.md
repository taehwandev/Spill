# Feature Intake

## Feature ID

`menu-bar-status-background-cleanup`

## Request

The maintainer asked to refine the status UI next to the macOS clock. The current menu bar status segments draw visible rounded backgrounds, and the requested change is to remove those backgrounds so the area reads cleaner. The existing glance values and click behavior should remain intact.

## User Problem

The clock-area status UI looks visually heavier than a native menu bar utility should. Removing the chip backgrounds reduces clutter while preserving the glanceable CPU, memory, Caffeine, and Spill trigger affordances.

## Necessity Assessment

- Product direction: this supports the compact, glance-first menu bar surface.
- Ownership: Spill owns this custom `NSStatusItem` drawing.
- Scope: this is a narrow menu bar rendering change.
- API and permission impact: no private APIs, fragile behavior, or new permissions.
- Cost of deferral: the menu bar status item remains visually heavier next to the clock.

Decision: `build`

Reason: The request aligns with the compact tray direction and only changes existing public AppKit rendering.

## Ambiguity Gate

Use `.agents/workflows/ambiguity-gate.md` before PRD authoring.

Clarity: `clear`

Unknown classification:

- blocker: none.
- researchable: location of the clock-area status UI implementation; resolved in `MenuBarStatusContentView`.
- assumable: keep the same visible status segments and click targets; remove visual backgrounds only.
- out-of-scope: redesigning the panel, changing status providers, changing menu bar placement, or adding private APIs.

Resolved inputs:

- maintainer: remove the status UI backgrounds next to the clock and make it cleaner.
- repo-research: PRD/ARD require a single visible status item and compact glance UI; `MenuBarMetricChipView` draws the rounded background with a layer color.
- assumption: normal status icons can use the native label color, with active and warning states retaining color for attention.

## PRD Authoring Gate

The goal, scope, value, UI behavior, feasibility, permission impact, and distribution impact are clear enough to proceed. No maintainer clarification is required.

## Clarifying Questions

Questions:

- none.

## Target User

Users who keep Spill visible near the macOS clock and want a quieter menu bar.

## Proposed Product Shape

The single Spill menu bar item continues to show the Spill trigger and enabled glance values. Individual status segments no longer draw rounded colored backgrounds. Normal status icons use the native menu bar label tone, while active or warning states can still use color.

## Constraints

- macOS/public API constraints: keep using `NSStatusItem`, `NSStatusBarButton`, and AppKit views.
- permission constraints: no new permissions.
- distribution constraints: no private frameworks or spacer status items.
- performance constraints: no additional polling or drawing timers beyond existing trigger animation.

## Non-goals

- Change which status modules are enabled.
- Change Caffeine or panel toggle click behavior.
- Change panel UI.
- Add preferences for background style.

## Open Questions

- none.

## Decision

Status: `accepted`

Reason: Small, reversible, public-API UI cleanup that supports Spill's compact menu bar direction.
