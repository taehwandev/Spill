# Detailed PRD: Status Trigger Hit Target

## PRD Authoring Gate

`00-intake.md` has `Decision: build` and `Clarity: clear`.

## Summary

Ensure the menu bar item always includes a dedicated Spill trigger hit target
when status chips are visible. Status actions such as Caffeine can remain
clickable, but they must not replace the user's ability to open the panel.

## Resolved Inputs

- maintainer decisions: clicking the menu bar item should open the panel.
- repo-researched facts: the status item can render only status chips, and
  Caffeine chip clicks do not call the panel toggle.
- assumptions: a leading droplet chip is the smallest clear trigger affordance.

## Goals

- Preserve a visible panel trigger while status chips are enabled.
- Keep Caffeine direct-toggle behavior scoped to the Caffeine chip.
- Make hit testing deterministic and unit-covered.

## Non-goals

- Change status module preferences.
- Change right-click context menu contents.
- Change panel sizing or layout.

## User Stories

- As a user, I want to click the Spill droplet in the menu bar to open the panel.
- As a user, I want the Caffeine chip to remain a quick toggle.

## UX Requirements

### Entry Point

The leading droplet chip in the status item opens or closes the panel.

### Layout

When status chips are present, the order is Spill trigger, then status action
chips such as Caffeine, CPU, and Memory.

### States

- loading: unchanged.
- empty: when no status chips are enabled, the existing icon-only trigger
  remains.
- unavailable: unavailable status chips remain visible but do not remove the
  trigger.
- permission required: unchanged.
- success: clicking the trigger opens the panel.
- failure: if a status action fails, panel trigger remains available.

## Functional Requirements

1. Add a `trigger` status segment kind.
2. Prepend a trigger segment whenever status content chips are displayed.
3. Route only Caffeine chip clicks to Caffeine start/stop.
4. Route trigger and non-action status chip clicks to panel toggle.
5. Update hit-testing tests for trigger, Caffeine, and CPU segment order.

## Behavior Scenarios

### Caffeine Enabled

Given Caffeine is enabled in the menu bar
When the status item renders
Then a Spill trigger chip appears before the Caffeine chip.

### Trigger Click

Given status chips are visible
When the user clicks the Spill trigger chip
Then Spill toggles the panel.

### Caffeine Click

Given the Caffeine chip is visible
When the user clicks the Caffeine chip
Then Spill starts or stops Caffeine without opening the panel.

## Acceptance Criteria

- Menu bar status content includes a dedicated trigger segment before status
  chips.
- Hit testing distinguishes trigger, Caffeine, and CPU regions.
- Targeted unit test passes.
- Full unit, build, and smoke checks pass.

## Metrics

- perceived latency: no change.
- reliability: panel trigger remains available regardless of enabled status
  chips.
- resource use: no new background work.

## Rollout

- MVP: leading trigger chip and hit-test coverage.
- later: optional tooltip polish if users need clearer affordance.

## References

- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Tests/SpillTests/MenuBarStatusContentViewTests.swift`
