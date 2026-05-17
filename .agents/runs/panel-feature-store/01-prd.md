# Detailed PRD: Panel Feature Store

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, clarity is `clear`, and there are no
blocking clarifying questions.

## Summary

Introduce and finish the behavior-preserving panel feature store slice. The
panel should continue to look and behave the same, while its display item,
pinned item, action item, status module, readiness, detail target, and action
feedback state move out of `SpillBarView` and into a testable store/state
layer.

## Resolved Inputs

- maintainer decisions: use a lightweight React-style Feature Store
  architecture and prioritize verification.
- repo-researched facts: ARD-008 defines the migration order and naming rules;
  `SpillBarView` currently observes several objects and derives panel state
  locally.
- assumptions: this slice is internal only and must not change user-visible
  behavior.

## Goals

- Add `PanelState`, `PanelAction`, and `PanelStore` for the first panel
  feature-store slice.
- Move current panel derivation out of `SpillBarView`.
- Move panel pinning, menu bar action feedback, window action feedback, and
  status-detail target state behind typed `PanelAction` events.
- Preserve existing panel layout, labels, controls, shortcuts, and feedback.
- Add focused tests for state derivation.
- Keep existing smoke verification passing.

## Non-goals

- No visual redesign.
- No new panel controls.
- No change to Caffeine, status, AI, menu bar scanning, or window action user
  behavior.
- No global app state or reducer framework.
- No distribution or installer changes.

## User Stories

- As a user, I want the panel to keep behaving the same after the refactor.
- As a maintainer, I want panel rendering inputs to come from a feature store so
  future changes are easier to reason about and test.
- As a maintainer, I want automated checks that prove empty, scanning,
  permission-required, and ready states still derive correctly.

## UX Requirements

### Entry Point

The entry point remains the existing menu bar trigger and panel.

### Layout

The compact panel layout remains unchanged.

### States

- loading: scanning state remains visible when the scanner is active and no
  display items are available.
- empty: empty state remains visible when no display/action items are available.
- unavailable: disabled action states remain represented by existing action
  models.
- permission required: Accessibility-required state remains visible when the
  app is not trusted.
- success: pinning and action success feedback remains visible in the header.
- failure: action failure feedback remains visible in the header.

## Functional Requirements

1. `PanelStore` must expose a published `PanelState`.
2. `PanelState` must include display items, pinned items, display action items,
   action items, visible status modules, and the current readiness state.
3. `PanelStore` must recompute state from `SpillSettings`,
   `AXMenuBarItemScanner`, and Accessibility trust.
4. `SpillBarView` must render from the derived state instead of recomputing
   panel display state directly.
5. `PanelStore` must handle pinning, menu bar action feedback, window action
   feedback, and status-detail target changes through typed actions.
6. The refactor must preserve existing menu bar action execution, pinning,
   status details, AI details, footer behavior, and window action behavior.

## Behavior Scenarios

### Main Path

Given Accessibility is trusted and detected menu bar items exist
When the panel renders
Then it shows the same ready state, item count, pinned items, and action grid as
before.

### Permission State

Given Accessibility is not trusted
When the panel renders
Then the header and menu bar section continue to show permission-required state.

### Scanning State

Given Accessibility is trusted, the scanner is active, and there are no display
items
When the panel renders
Then the menu bar section continues to show scanning state.

### Empty State

Given Accessibility is trusted, scanning is not active, and there are no display
items
When the panel renders
Then the panel continues to show the empty action state.

### Action Feedback

Given a user pins an item or runs a menu bar or window action
When the panel handles the event
Then `PanelStore` stores the same header feedback message the view previously
showed.

### Status Detail

Given a user opens a system or AI detail popover
When the panel handles the event
Then the selected detail target is represented in `PanelState`.

## Acceptance Criteria

- `SpillBarView` no longer owns the display/pinned/action/panel-state
  derivation.
- Focused store tests cover ready, pinned, permission-required, scanning, empty,
  pinning feedback, action feedback, and status-detail target state.
- `swift test` passes.
- `swift build` passes.
- `./scripts/build-app.sh` passes.
- Existing panel smoke verification passes.
- Existing workflow verification passes.

## Metrics

- perceived latency: no intentional change.
- reliability: existing smoke checks remain green.
- resource use: no additional polling or background loops.

## Rollout

- MVP: derive panel rendering state through `PanelStore` with behavior
  preserved.
- later: continue slimming `AppDelegate` and introduce adapters for AppKit
  bridge callbacks in separate slices.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelState.swift`
