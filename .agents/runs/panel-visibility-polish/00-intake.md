# Feature Intake

## Feature ID

`panel-visibility-polish`

## Request

The maintainer reported that the panel and menu bar glance hide too much useful
information, show confusing gray `--` CPU values, and make Settings/Quit too
hard to find. They also asked for real menu bar icons, one-decimal metric
values, and a less cramped panel layout.

## User Problem

The current UI looks unfinished because key status values are clipped or hidden,
unavailable CPU samples look like failures, and important controls are buried in
a right-click menu. Users cannot trust the tray if the displayed numbers lack
precision or if the app does not clearly explain what CPU and memory values mean.

## Necessity Assessment

Decision: `build`

Reason: This is necessary polish for the current compact tray. It improves
existing public-API status and action surfaces without adding private APIs,
changing the no-spacer architecture, or turning Spill into a full monitoring
dashboard.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none
- researchable: current metric definitions, panel layout, status item rendering,
  and tests are in the repository.
- assumable: use one-decimal values by default; treat initial CPU samples as
  sampling/zero rather than gray unavailable; add visible Settings/Quit controls
  in the panel header.
- out-of-scope: exact numerical parity with third-party monitors that use
  different formulas, storage statistics, network throughput, and a large
  dashboard layout.

Resolved inputs:

- maintainer: make menu bar icons real, expose useful CPU/memory information,
  stop showing confusing gray CPU `--`, improve panel UI, and make Settings/Quit
  visible.
- repo-research: Spill currently samples CPU with `host_statistics`, memory with
  `vm_statistics64`, and shows menu bar CPU/memory via compact AppKit chips.
- assumption: one-decimal values and explicit details are the smallest useful
  fix before adding new providers such as disk throughput or memory pressure.

## PRD Authoring Gate

The request, expected UI behavior, product value, feasibility, permission impact,
and distribution impact are clear enough to proceed.

## Clarifying Questions

Questions:

- none

## Target User

Mac users relying on Spill as a quick control tray who need status values,
shortcuts, settings, and quit controls to be visible and trustworthy at a glance.

## Proposed Product Shape

The panel should become wider and less cramped, with clearer status cards,
visible Settings/Quit header controls, and full status detail text inside the
main panel. The menu bar glance should use real SF Symbol icons and one-decimal
values by default.

## Constraints

- macOS/public API constraints: use existing AppKit, SwiftUI, host statistics,
  and vm statistics only.
- permission constraints: no new permissions.
- distribution constraints: no private APIs or signing changes.
- performance constraints: keep CPU sampling conservative and avoid blocking
  panel presentation.

## Non-goals

- Exact parity with iStat Menus, Activity Monitor, or third-party widgets.
- Disk, temperature, per-app memory, upload/download counters, or memory pressure
  providers in this slice.
- A large dashboard or always-open monitor.

## Open Questions

- none

## Decision

Status: `accepted`

Reason: The slice fixes visible trust and usability problems in existing
surfaces while preserving the compact tray product boundary.
