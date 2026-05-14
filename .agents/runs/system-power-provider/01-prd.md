# Detailed PRD: System Power Provider

## Summary

Add a read-only system power provider that reports battery percentage, charging state, on-battery state, or external power state. The value appears as a compact footer item in the Spill panel, complementing memory and action status without expanding the panel into a dashboard.

## Goals

- Provide one more real status signal in the Stitch-inspired compact panel.
- Use only public macOS APIs that are suitable for open-source distribution.
- Keep the visible UI to an icon plus a short value.
- Make mapping logic deterministic and covered by unit tests.

## Non-goals

- No power controls.
- No battery history or charts.
- No notifications.
- No private API usage.
- No settings UI for this first slice.

## User Stories

- As a MacBook user, I want to see battery percentage and charging state in Spill so I can keep the menu bar cleaner.
- As a desktop Mac user, I want Spill to avoid fake battery values and show external power or unavailable state cleanly.
- As a maintainer, I want a tested provider pattern that can be reused for future CPU, AI, and window-management status.

## UX Requirements

### Entry Point

The value is visible in the existing Spill panel footer after opening the menu bar trigger or fallback launcher.

### Layout

The footer includes a small SF Symbol and a short value:

- battery percentage such as `83%`
- `AC` for external power without a battery
- `N/A` when power state cannot be read

### States

- loading: no loading state for MVP; the read is synchronous and cheap.
- empty: not applicable.
- unavailable: show `N/A` with secondary tint.
- permission required: not applicable; power status needs no Accessibility permission.
- success: show percentage or `AC` with normal/active/warning tint.
- failure: same visual treatment as unavailable.

## Functional Requirements

1. Add a system power provider that produces a `SpillStatusItem`.
2. Read current power state through public IOKit power source APIs.
3. Convert raw readings into stable display states.
4. Surface the value in `SpillBarView` footer without changing panel size.
5. Add unit tests for mapping, thresholds, unavailable state, and status item conversion.

## Acceptance Criteria

- `swift build` passes.
- `swift test` passes.
- `.agents/scripts/workflow.py verify` passes.
- `.agents/scripts/workflow.py run-gates` passes.
- The panel footer remains compact and includes power state.
- Macs without battery hardware do not show fake percentages.

## Metrics

- perceived latency: no visible delay when opening the panel.
- reliability: provider returns `N/A` instead of crashing on missing or malformed IOKit data.
- resource use: no background polling loop in this slice.

## Rollout

- MVP: direct provider read and compact footer display.
- later: provider registry, refresh cadence, richer battery metadata, optional settings.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/design/stitch.md`
- `Sources/Spill/Providers/SystemMemoryProvider.swift`
