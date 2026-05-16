# Intake: Window Quick Actions

## Request

Add small Rectangle-like focused-window controls to the Spill panel. Users should be able to move the current focused window to the left half, right half, center, maximize it, move it to the next display, and restore the previous frame.

## Why Now

The panel already aggregates status, AI state, and menu bar actions. Window actions complete the compact control tray direction by adding high-frequency Mac controls without opening a separate utility.

## Necessity

Decision: `build`

### Reasoning

Window quick actions are an active roadmap milestone. They can be implemented with public Accessibility APIs already required by Spill's menu bar action features and can share the existing `SpillAction` model.

### Cost Of Skipping

The panel would remain mostly status and menu-bar-item focused, leaving a core compact control workflow unimplemented.

## Users

- Keyboard and menu bar users who want quick window placement.
- Users who want simple Rectangle-like commands without another visible menu bar app.
- Maintainers validating the action model against non-menu-bar actions.

## Scope

- Add focused window frame planning.
- Add public Accessibility write path for window position and size.
- Add quick action buttons to the existing action row.
- Add best-effort restore for the previous frame.
- Add tests for deterministic frame planning.

## Non-Goals

- No snapping grid editor.
- No custom keyboard shortcuts in this slice.
- No per-app rules.
- No private window server APIs.
