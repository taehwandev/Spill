# Detailed PRD: Stitch-Inspired Panel Shell

## Summary

Spill should ship a compact panel shell based on the Stitch `Spill Multi-Widget Panel` reference. The first implementation will use the same product shape: header, status area, action area, and footer. Every visible value must come from current Spill state, so unavailable provider concepts are represented through permission, scanning, empty, and ready states.

## Goals

- Make the panel feel intentional and polished instead of a raw icon tray.
- Show current Accessibility readiness, scanner activity, and available action count.
- Preserve click-through behavior for detected menu bar actions.
- Keep the panel small enough to sit below the notch or menu bar trigger.
- Establish a design pattern that future system, AI, and window providers can reuse.

## Non-goals

- Do not add real system monitoring.
- Do not add AI status.
- Do not add window-management actions.
- Do not render sample, placeholder, or fake metrics.
- Do not redesign preferences.
- Do not change the menu bar trigger architecture.

## User Stories

- As a user, I want to see whether Spill is ready before I click hidden menu bar actions.
- As a user, I want scanning and permission states to be obvious in the compact panel.
- As a user, I want detected actions to remain clickable from the panel.
- As a contributor, I want clear UI sections that future providers can fill without redesigning the panel again.

## UX Requirements

### Entry Point

The existing menu bar trigger opens the panel. The trigger behavior, menu bar item length, and Accessibility scanner entry points remain unchanged.

### Layout

The compact panel contains four sections:

- Header: app identity, current state subtitle, and a colored state dot.
- Status: two meter rows for `ACCESS` and `ACTIONS`.
- Actions: horizontal strip of detected menu bar action buttons or an inline state message.
- Footer: compact icons for Accessibility readiness, scanner activity, optional count badge, and current time.

### States

- loading: show a spinner and `Scanning` in the action section while no actions are ready.
- empty: show `No Items Detected` or `No Selected Items` based on display mode.
- unavailable: disable individual action buttons when the scanner reports they cannot be pressed.
- permission required: show `Accessibility Required`, orange state, and `ACCESS Needed`.
- success: show green ready state, action count, and clickable action buttons.
- failure: no new failure source exists in this slice; future providers must map errors into explicit state rows.

## Functional Requirements

1. The panel uses the existing `AXMenuBarItemScanner` and `SpillSettings` objects.
2. The panel does not create new providers or timers.
3. `ACCESS` reflects `AccessibilityPermission.isTrusted`.
4. `ACTIONS` reflects the current displayed item count.
5. Action buttons call `scanner.pressItem(withID:)` and dismiss the panel on success.
6. The panel uses a compact fixed width and taller shell to support state sections.
7. The panel remains anchored through the existing notch-aware layout.
8. The UI includes no fake CPU, memory, battery, AI, or provider data.

## Acceptance Criteria

- `swift build` passes.
- `swift test` passes.
- Workflow gates pass.
- Runtime smoke verification passes.
- The panel source contains no fake system metrics.
- Permission, scanning, empty, and ready states are represented in the view.
- Existing action click behavior remains wired through the scanner.

## Metrics

- perceived latency: panel display should stay instant because no new data fetch starts on open.
- reliability: the shell should work when Accessibility is denied, scanning, empty, or populated.
- resource use: no new background loops, timers, network calls, or screen capture.

## Rollout

- MVP: native SwiftUI shell using current app state only.
- later: replace temporary status meters with real provider-backed system, AI, and window-management sections.

## References

- `.agents/design/stitch.md`
- Stitch project `Spill: Menu Bar Manager`
- Stitch screen `Spill Multi-Widget Panel`
- `Sources/Spill/Panel/SpillBarView.swift`
