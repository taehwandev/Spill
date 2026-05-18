# Detailed PRD: Panel Glass Footer Contrast

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, `Clarity: clear`, and no blocking clarifying questions.

## Summary

Improve the dashboard footer/menu bar so it remains readable over transparent Liquid Glass-style surfaces. The footer should keep its clean, background-free look while adapting text hierarchy for both bright and dark backgrounds. Active blue accents should be replaced with a brighter teal tone where the same contrast problem appears in the panel and clock-adjacent status item.

## Resolved Inputs

- maintainer decisions: do not restore visible backgrounds; adapt the information over transparent glass; avoid weak blue accents on bright glass.
- repo-researched facts: `SpillFooterView` controls the compact footer strip with AX, scan, Caffeine, power, item count, and time.
- assumptions: values are the most important information and should use adaptive primary foreground; status color should be concentrated on icons.

## Goals

- Keep the footer visually transparent.
- Make footer values readable on bright backgrounds.
- Preserve readable behavior on darker backgrounds.
- Keep status meaning visible without making all text colored.
- Replace weak active-blue accents with teal accents in the affected panel and menu bar surfaces.
- Avoid provider, permission, or panel sizing changes.

## Non-goals

- Add a footer background capsule.
- Add pixel sampling of the desktop or windows.
- Redesign other panel sections.
- Add new settings.

## User Stories

- As a user, I want the dashboard footer values to remain visible over white or bright glass.
- As a user, I want dark backgrounds to remain readable without the footer looking heavier.
- As a user, I want status meaning to remain visible through icons and color.

## UX Requirements

### Entry Point

The existing Spill panel footer remains at the bottom of the dashboard.

### Layout

The same footer items remain in the same order. The footer background is not restored. Each item uses a three-level contrast recipe: colored icon, readable secondary label, primary value. Active or refreshing accents use teal instead of blue.

### States

- loading: unchanged.
- empty: count and time still use primary values.
- unavailable: icon is muted, value remains readable.
- permission required: AX icon warns, value remains primary.
- success: normal states use readable positive/active icon tones with primary values.
- failure: warning icon appears, failure value remains primary.

## Functional Requirements

1. Footer values must not inherit low-contrast status tint.
2. Footer labels should remain visually secondary but readable over bright glass.
3. Footer icons should carry status color.
4. The footer should not draw a visible capsule background.
5. Active/refreshing status accents in the panel and clock-adjacent status item should use teal instead of blue.
6. The contrast recipe should be represented in a testable style model.
7. Existing panel content and action behavior must remain unchanged.

## Behavior Scenarios

### Bright Glass

Given the panel footer is shown over a bright surface
When the user reads time, item count, power, or Sleep Guard state
Then the value text uses adaptive primary foreground instead of a pale status tint.

### Dark Glass

Given the panel footer is shown over a dark surface
When the user reads footer status
Then labels, values, and icons remain readable without restoring a background capsule.

### Warning State

Given Accessibility is not trusted or Sleep Guard has an error
When the footer renders
Then the icon uses a warning tone while the value remains high contrast.

## Acceptance Criteria

- Footer values use primary foreground role.
- Footer icons keep semantic status roles.
- The footer background capsule is not rendered.
- Active/refreshing accent color is teal in the panel and menu bar status renderer.
- Unit tests cover the contrast role mapping.
- `swift test`, `swift build`, and panel smoke checks pass.

## Metrics

- perceived latency: no change.
- reliability: no provider or action behavior changes.
- resource use: no new polling or screen sampling.

## Rollout

- MVP: adaptive semantic footer contrast.
- later: actual material luminance sampling only if semantic contrast is insufficient.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/design/stitch.md`
- `Sources/Spill/Panel/SpillFooterView.swift`
