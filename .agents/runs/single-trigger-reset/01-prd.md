# PRD: Single Trigger Reset

## Summary

Replace the spacer-based menu bar architecture with one visible Spill trigger. The trigger opens the panel and exposes the existing context menu. Spill should stop reserving notch-width menu bar space.

## Goals

- Keep one visible fixed-width `NSStatusItem`.
- Remove hidden spacer status item creation.
- Keep existing click and right-click behavior.
- Keep the panel and scanner behavior unchanged.
- Make architectural code gates pass.

## Non-goals

- No panel redesign.
- No provider implementation.
- No private menu bar manipulation.
- No window management features.

## User Stories

- As a user, I can see one Spill icon in the menu bar.
- As a user, I can click the Spill icon to show or hide the panel.
- As a user, I can right-click or Control-click the icon to open the menu.
- As a maintainer, I can trust that `StatusItemController` owns one status item.

## UX Requirements

### Entry Point

One fixed-width status item with the existing ellipsis symbol.

### States

- normal: ellipsis icon is visible.
- active: button state reflects visible panel state.
- menu: right-click or Control-click opens the existing menu.
- unavailable: no special unavailable state is needed for the trigger.

## Functional Requirements

1. `StatusItemController` creates exactly one `NSStatusItem`.
2. No code derives a status item length from notch width.
3. No hidden spacer item is created.
4. Tooltip copy continues to reflect panel state and detected item count.
5. Existing refresh, preferences, and quit menu actions still exist.

## Acceptance Criteria

- `swift build` passes.
- `python3 .agents/scripts/workflow.py code-gates` passes.
- `StatusItemController` has no spacer logic.
- `MenuBarNotchGeometry` no longer exposes status item reserve width.

## Metrics

- perceived latency: no added work on refresh.
- reliability: trigger should not depend on oversized status item behavior.
- resource use: no additional polling or observers.

## Rollout

- MVP: single trigger only.
- later: panel sections provide the actual product value.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
