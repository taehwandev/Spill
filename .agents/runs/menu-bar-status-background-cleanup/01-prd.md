# Detailed PRD: Menu Bar Status Background Cleanup

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, `Clarity: clear`, and no blocking clarifying questions.

## Summary

Remove the rounded colored backgrounds from Spill's clock-area menu bar status segments while keeping the existing single status item, visible status values, tooltips, and click behavior. The result should feel closer to a native macOS menu bar indicator: compact text and icons without pill-like containers.

## Resolved Inputs

- maintainer decisions: the status UI next to the clock should lose its visible backgrounds and look cleaner.
- repo-researched facts: `MenuBarStatusContentView` installs `MenuBarMetricChipView` subviews; each chip currently creates a layer and fills it with a translucent state color.
- assumptions: enabled values, hit target widths, and segment order remain unchanged; normal icons use label color, with active/warning colors still available for state.

## Goals

- Remove visual chip backgrounds from menu bar status segments.
- Keep the Spill trigger, CPU, memory, and Caffeine menu bar affordances available.
- Preserve deterministic hit testing for Caffeine and panel toggle behavior.
- Keep the implementation inside the existing AppKit status item renderer.

## Non-goals

- Redesign the compact panel.
- Change status providers, refresh intervals, settings, or persistence.
- Add a visual style preference.
- Add another `NSStatusItem` or spacer.

## User Stories

- As a user, I want the status UI next to the clock to blend into the menu bar without colored pill backgrounds.
- As a user, I still want CPU, memory, Caffeine, and the Spill trigger to be readable and clickable when enabled.

## UX Requirements

### Entry Point

The existing Spill status item next to the macOS clock remains the entry point.

### Layout

The same icon and value segments appear in the same order and width. The segment containers are transparent instead of rounded colored chips. No panel layout changes are included; the Stitch panel mapping remains unchanged for this slice.

### States

- loading: unchanged; existing values remain until refresh.
- empty: unchanged icon-only fallback behavior.
- unavailable: unavailable icons remain subdued without a background fill.
- permission required: unchanged; no new permission state.
- success: status item renders with transparent segment backgrounds.
- failure: provider failures continue to render existing unavailable values.

## Functional Requirements

1. `MenuBarMetricChipView` must not draw a rounded background fill.
2. Normal status icons should use the native label tone instead of decorative mint/teal fills.
3. Active, refreshing, warning, and unavailable states should retain distinct icon coloring where useful.
4. Segment width and hit testing must remain stable.
5. The app must continue to use one visible `NSStatusItem`.

## Behavior Scenarios

### Main Path

Given CPU and memory menu bar status values are enabled
When Spill renders the status item next to the clock
Then the status segments show icons and values without rounded background fills.

### Caffeine Segment

Given the Caffeine segment is visible
When the user clicks the Caffeine region
Then Caffeine toggles as before and no background container is drawn around the segment.

### Unavailable Status

Given a status value is unavailable
When the menu bar status item renders
Then the unavailable icon appears subdued without a translucent background.

## Acceptance Criteria

- Menu bar status chip subviews do not set a layer background color.
- Existing hit-testing tests still pass.
- A focused test covers the absence of rounded chip backgrounds.
- `swift test` and `swift build` pass.

## Metrics

- perceived latency: no change.
- reliability: existing click regions and status fallbacks remain stable.
- resource use: no new polling, providers, or timers.

## Rollout

- MVP: remove chip backgrounds and keep existing behavior.
- later: consider a user-selectable compact style only if there is repeated demand.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/design/stitch.md`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Tests/SpillTests/MenuBarStatusContentViewTests.swift`
