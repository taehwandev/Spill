# Feature Intake

## Feature ID

`status-trigger-hit-target`

## Request

The maintainer reported that clicking the menu bar item does not open the panel.
Runtime smoke can open the panel programmatically, so the issue is specifically
the status-item hit target and click routing. Spill must keep a reliable panel
trigger even when menu bar status chips such as Caffeine are enabled.

## User Problem

Users cannot open the primary panel from the menu bar when the visible status
item is interpreted as a status-chip action instead of the Spill trigger.

## Necessity Assessment

- Product fit: the menu bar trigger is the primary entry point.
- Better owner: Spill owns status item hit target composition.
- Surface size: this is a small menu bar hit-target fix.
- Platform risk: no private APIs or new permissions.
- Cost of deferral: users can see a menu bar icon but cannot open the panel.

Decision: `build`

Reason: The app must always preserve a clickable Spill panel trigger.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none.
- researchable: current `StatusItemController` segment composition.
- assumable: Caffeine should remain directly clickable because that was an
  existing requested behavior.
- out-of-scope: redesigning the whole menu bar status system.

Resolved inputs:

- maintainer: clicking the menu bar item should open the panel.
- repo-research: when status segments exist, the button content can be only
  status chips; Caffeine clicks are routed away from panel toggle.
- assumption: add a dedicated leading Spill trigger chip and keep Caffeine
  direct-toggle behavior on its own chip.

## PRD Authoring Gate

Decision is `build` and clarity is `clear`.

## Clarifying Questions

Questions:

- none.

## Target User

Users with menu bar status items enabled, especially Caffeine-only display.

## Proposed Product Shape

When status chips are shown, the menu bar item starts with a small Spill droplet
trigger. Clicking that droplet opens/closes the panel. Clicking the Caffeine chip
continues to start/stop Caffeine.

## Constraints

- macOS/public API constraints: keep using `NSStatusItem` and `NSStatusBarButton`.
- permission constraints: no new permissions.
- distribution constraints: no signing or packaging changes.
- performance constraints: no background work.

## Non-goals

- Remove direct Caffeine toggle.
- Change right-click menu behavior.
- Change panel layout.

## Open Questions

- none.

## Decision

Status: `accepted`

Reason: A dedicated trigger hit target restores the primary entry point without
removing status actions.
