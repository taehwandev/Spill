# Detailed PRD: Panel Visibility Polish

## Summary

Panel Visibility Polish makes existing status and action surfaces readable,
precise, and easier to operate. The menu bar glance should show real metric
icons and one-decimal values. The panel should stop hiding useful CPU and memory
details, expose Settings/Quit controls, and use a wider layout that remains a
compact tray rather than a full dashboard.

## Resolved Inputs

- maintainer decisions: improve menu bar icons, CPU display, panel density,
  visible controls, and metric precision.
- repo-researched facts: the app already has CPU, memory, GPU, network, AI,
  window actions, and native right-click menu support.
- assumptions: one-decimal percent precision is the default; exact parity with
  other monitoring apps is out of scope because metric definitions differ.

## Goals

- Show menu bar CPU/memory with SF Symbol icons and one decimal place.
- Avoid confusing gray CPU `--` during initial sampling.
- Make CPU and memory definitions visible in the panel.
- Make Settings and Quit visible without requiring right-click discovery.
- Reduce cramped clipping by widening the panel within compact tray bounds.

## Non-goals

- Add storage, temperature, upload/download, per-app memory, or memory pressure
  providers.
- Replace Activity Monitor or iStat Menus.
- Use private APIs.

## User Stories

- As a user, I want CPU and memory values to show one decimal place so I can
  compare them with other tools more confidently.
- As a user, I want visible Settings and Quit buttons so I can operate the app
  without guessing the right-click menu.
- As a user, I want details in the main panel so useful status information is not
  hidden behind tiny popovers.

## UX Requirements

### Entry Point

Left click opens the panel. Right click still opens the native menu. Header
buttons expose Settings and Quit directly.

### Layout

The panel is wider, with status cards that include primary value and at least
one supporting detail. CPU and memory cards should expose the values already
available from provider detail rows.

### States

- loading: CPU may show `0.0%` with sampling/available context instead of `--`.
- empty: action rows still show clear empty states.
- unavailable: true failures can show unavailable detail, but the menu bar should
  not collapse into a gray `--` for normal initial CPU sampling.
- permission required: window/menu-bar action controls remain disabled with
  visible reason.
- success: action feedback remains in the header subtitle.
- failure: action failure still appears in the header subtitle.

## Functional Requirements

1. Default menu bar precision is tenths.
2. Menu bar chips use SF Symbol icons rather than plain color dots.
3. CPU unavailable initial samples render as a non-gray zero/sampling state.
4. Panel status cards expose key detail rows inline.
5. Panel header includes visible Settings and Quit controls.
6. Panel width and smoke limits are updated so text does not feel clipped.

## Behavior Scenarios

### Main Path

Given the app is running
When the user opens the panel
Then the panel shows status values, status details, actions, Settings, and Quit
without relying on hidden popovers for basic information.

### Relevant Edge States

Given CPU is still collecting its first usable sample
When the menu bar glance renders
Then CPU displays a stable zero/sampling value instead of a gray `--`.

## Acceptance Criteria

- Menu bar CPU/memory chips include metric icons.
- CPU/memory values use one decimal place by default.
- Settings and Quit are visible in the panel header.
- CPU and memory cards expose detail rows inline.
- `swift test` and panel layout smoke pass.

## Metrics

- perceived latency: panel still opens immediately; CPU refresh can update
  shortly after opening.
- reliability: metric definitions are stable and visible.
- resource use: no new polling loops beyond existing refresh cadence.

## Rollout

- MVP: improve current CPU, memory, header, and status UI.
- later: add memory pressure, storage, network throughput, or temperature as
  separate providers.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/design/stitch.md`
