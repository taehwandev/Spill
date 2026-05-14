# Feature Intake

## Feature ID

`power-footer-sleep-guard`

## Request

Add an option to hide the existing power footer status because macOS already exposes battery state for many users. Add a separate Sleep Guard control that is off by default and only prevents idle sleep after the user chooses a time duration. The control must be visible and easy to manage inside Spill without adding another macOS menu bar item.

## User Problem

Battery status is useful but often duplicated by macOS. Preventing idle sleep is an actual action, not only a status signal, so it needs a dedicated control with clear active state and remaining time.

## Necessity Assessment

- Product fit: yes, compact controls are part of Spill's tray direction.
- Best owner: Spill should own the compact control entry point; macOS owns global power settings.
- Compactness: yes, if Sleep Guard stays as a small footer control.
- API and distribution impact: public IOKit power assertions are acceptable for Developer ID distribution.
- Cost of skipping: users cannot tune duplicated power status and cannot manage a common temporary sleep-prevention workflow from Spill.

Decision: `build`

Reason: The slice adds a small, useful control while respecting the single status item and public API constraints.

## PRD Authoring Gate

The maintainer clarified that Sleep Guard must be off by default and must activate only for a selected duration. The MVP excludes always-on behavior. No further clarification is required for this slice.

## Clarifying Questions

Questions:

- None for this MVP.

## Target User

Mac users who want a compact tray for temporary operational controls without installing a separate awake utility.

## Proposed Product Shape

Preferences has options for showing the power footer and choosing whether Sleep Guard also keeps the display awake. The panel footer includes a Sleep Guard icon. Clicking it opens duration choices. When active, the footer shows remaining time and clicking the menu can stop it.

## Constraints

- macOS/public API constraints: use IOKit power assertions only.
- permission constraints: no Accessibility, Screen Recording, or network permission is added.
- distribution constraints: no private API and no extra menu bar item.
- performance constraints: Sleep Guard remains idle when off.

## Non-goals

- No always-on or indefinite mode.
- No schedule automation.
- No global sleep settings editing through `pmset`.
- No separate macOS status item.

## Open Questions

- Later slices can decide whether Sleep Guard should support custom durations.

## Decision

Status: `accepted`

Reason: The behavior is clear, bounded, and useful for the compact control tray.
