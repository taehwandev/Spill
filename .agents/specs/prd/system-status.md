# System Status PRD

## Document Contract

- Status: active
- Audience: product, engineering, and QA
- Purpose: define local system metrics, presentation, and resource constraints
- Source of truth: this document owns system-status product requirements
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md),
  [Menu Bar Surface](menu-bar-surface.md), [Compact Panel](compact-panel.md)

## Initial Metrics

- Memory usage
- CPU usage
- Battery percent/state
- Network status

## Requirements

- Read-only pills.
- Compact labels.
- Refresh interval configurable later; use a conservative default.
- CPU usage defaults to a multicore/system-wide interpretation. Preferences
  should not expose a separate option to choose among multiple CPU calculation
  modes unless a later PRD defines a real user workflow for that distinction.
- Avoid high CPU overhead.
- Closing Preferences releases its hosted UI and window-scoped preview work;
  hidden configuration surfaces must not keep animations or layout passes alive.

## Acceptance

- Metrics update without blocking UI.
- Missing metrics show a quiet unavailable state.
- Redundant CPU mode settings are removed from Preferences and no longer affect
  status display.
- Reopening Preferences recreates its UI normally after the previous window was
  closed and released.

## Open Coverage Decision

The roadmap and current implementation present Storage as a primary panel
metric, while the former root PRD listed Battery and Network as the initial
metric set. Product review must choose the canonical MVP metric set before this
section is treated as complete.

## Verification

- Verify metrics refresh without blocking the main UI.
- Verify hidden or unavailable metrics do not keep unnecessary polling alive.
- Verify the accepted metric set matches panel, menu bar, Preferences, tests,
  and roadmap documentation.
