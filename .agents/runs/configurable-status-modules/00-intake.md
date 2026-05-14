# Feature Intake

## Feature ID

`configurable-status-modules`

## Request

Users need CPU and memory meters to be useful without becoming a large dashboard. The compact panel should allow status modules to be reordered and turned on or off. Disabled modules must not perform their backing work, including provider refreshes, because an off state should mean the feature is functionally inactive rather than merely hidden.

## User Problem

System status signals are only useful if the user can decide which signals deserve space in the compact tray. Fixed ordering makes the panel feel less personal, and hidden-but-still-running providers waste work and may surprise users.

## Necessity Assessment

- Product fit: yes, because compact tray composition is part of Spill's core direction.
- Best owner: Spill, because macOS does not configure this custom panel.
- Compactness: yes, if the MVP only covers compact system meters.
- API and distribution impact: no private APIs, fragile behavior, or extra permissions.
- Cost of skipping: the panel becomes harder to tune as CPU, memory, AI, and other status modules are added.

Decision: `build`

Reason: Configurable status modules are core panel composition behavior and keep future providers from crowding the compact UI.

## PRD Authoring Gate

The maintainer clarified that CPU and memory style meters should be reorderable and switchable. The maintainer also clarified that disabled modules should not actually run. No further clarification is required for the MVP because the scope is limited to system status meters already present or already approved for panel integration.

## Clarifying Questions

Questions:

- None for this MVP.

## Target User

Mac users who want a compact tray with visible system state but do not want a large dashboard.

## Proposed Product Shape

Preferences expose a small status module list. Each module can be enabled or disabled and moved up or down. The panel renders enabled meters in the configured order. Disabled modules are omitted from the panel and skipped during status refresh.

## Constraints

- macOS/public API constraints: use existing public system providers only.
- permission constraints: no additional permission requirement.
- distribution constraints: no private API, no notarization-hostile behavior.
- performance constraints: disabled providers must not refresh.

## Non-goals

- Full dashboard layout.
- Drag-and-drop configuration.
- Configuring menu bar action icons.
- AI or network provider configuration in this slice.

## Open Questions

- Later slices should decide whether footer items such as power move into the same configurable meter strip.

## Decision

Status: `accepted`

Reason: The behavior is necessary, feasible, and small enough for the current compact panel direction.
