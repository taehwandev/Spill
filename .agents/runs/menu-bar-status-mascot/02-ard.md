# Deferred ARD Note: Menu Bar Status Mascot

## Architecture Gate

This run is deferred and does not authorize implementation.

## Constraints To Preserve Later

- Keep ARD-001 intact: use one fixed-width status item and no spacer
  architecture.
- Keep menu bar state presentation behind `StatusItemController` and related
  menu bar rendering helpers.
- Keep animation lightweight and event-driven rather than constantly ticking.
- Keep Caffeine state sourced from `SleepGuardController`.
- Keep status state sourced from existing provider/store models.

## Open Decisions

- Mascot asset format: SF Symbol composition, AppKit drawing, bitmap frames, or
  another lightweight representation.
- Caffeine control model: separate adjacent hit target, modifier click, context
  menu item, or panel-only action.
- State priority: which state wins when Caffeine, scanning, warnings, and panel
  visibility overlap.
- Animation cadence: how often active states may animate without becoming
  distracting.

## Implementation Boundary

No source files are changed for this deferred run.
