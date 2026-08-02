# Stitch Design Source

Stitch is the source of truth for future Spill UI implementation.

Do not commit API keys, access tokens, or MCP configuration values to this repository.

## Project

- Title: `Spill: Menu Bar Manager`
- Project ID: `7783735116268422117`
- Project resource: `projects/7783735116268422117`

## Screens

- `Spill Multi-Widget Panel`
  - Screen ID: `71428f70bff3457281942a56f691a56b`
  - Resource: `projects/7783735116268422117/screens/71428f70bff3457281942a56f691a56b`
- `Spill Advanced Feature Settings`
  - Screen ID: `1c917f2e89a2420994f59abf1134f340`
  - Resource: `projects/7783735116268422117/screens/1c917f2e89a2420994f59abf1134f340`
- `Spill Advanced Feature Settings`
  - Screen ID: `c2c78f80b8d849b58bd7377d1706f85e`
  - Resource: `projects/7783735116268422117/screens/c2c78f80b8d849b58bd7377d1706f85e`
- `Spill Pro: Structured Token Dashboard`
  - Screen ID: `336bc2c93e6343529feff3317f5da0d7`
  - Resource: `projects/7783735116268422117/screens/336bc2c93e6343529feff3317f5da0d7`

## Implementation Rule

Do not implement or redesign panel UI from inference alone. Before a UI-scoped feature, inspect the relevant Stitch screen and document the mapping from Stitch sections to SwiftUI components in that feature run.

Non-UI foundation work, such as provider models and test infrastructure, may proceed without changing panel UI.

## Current Panel Mapping

The first native panel shell maps `Spill Multi-Widget Panel` to current app state only:

- Stitch header becomes `SpillPanelState` in `SpillBarView`.
- Stitch performance cards become the real `MEMORY` provider meter and current `ACTIONS` meter.
- Stitch active-app row becomes the current detected action strip.
- Stitch quick status pill becomes the footer with Accessibility, scan, power, count, and time indicators.

Do not render CPU, battery details beyond compact power state, AI, or window-management values until real providers are implemented and verified.

## Current Spill Glance Mapping

The `Spill Multi-Widget Panel` screen was inspected for the Spill Glance slice.
The top-right System Flow card supplies the density, compact status hierarchy,
and rounded material vocabulary; the user-provided macOS Control Center
reference supplies the dark glass treatment.

- The System Flow card's small icon, label, and value hierarchy maps to compact
  All Today and rolling Work Type cells. Optional Codex/Claude/Antigravity cells
  use short `CX`/`CL`/`AG` labels beside their established color cues so All
  style remains identifiable without repeating full tool names.
- The screen's compact controls map to one `SpillGlanceSurface` continuous
  rounded glass group with subtle internal separators, not multiple floating
  capsules. The group remains horizontal: All style shows selected cells in one
  row with fixed breathing room and clear dividers, while Ticker style uses one
  fixed-width rotating cell and the persistent settings action. With Reactive
  View on, that cell carries whichever module just changed and rests on All
  Today when nothing has; with it off, Ticker gives Work one global slot and
  advances its internal value when that slot returns.
- Performance and active-app rows do not map into Glance. The surface renders
  only the existing current-day token panel summary and rotates its task
  categories in existing usage order.
- The Stitch sidebar, header, pagination, and footer do not map into Glance.
- `SpillGlancePanelController` owns display-relative placement; the first-launch
  default remains top-center, while persisted edge/corner anchors and free
  visible-frame ratios adapt to display geometry and support both top and bottom
  placement. Placement is not a visual component and does not derive layout
  from the Stitch desktop canvas.
- Preferences use the existing `PreferenceCard` vocabulary instead of copying
  the Stitch sidebar.

Visual verification must preserve a horizontal row no taller than 34 points,
content-hugging All style, stable fixed-width Ticker style with a short
in-place crossfade on the active rotation cadence
(five seconds while rolling, one dwell per queued change while reactive), one rounded
continuous glass layer without stacked tint material, clear internal separation,
short visible tool labels, fixed-size legible monospaced token
values contained inside stable measured cell budgets without crossing dividers,
a compact final settings action, draggable display-relative top/bottom
placement, default full-screen hiding, and visible clearance from the macOS
menu bar.

## Current Token Metering Dashboard Mapping

`Spill Pro: Structured Token Dashboard` is the current layout reference for
the local token metering dashboard.

- Top header maps to `TokenMeteringDashboardView.header`.
- Left filter rail maps to the period/tool filters, stable opaque folder
  filters, and future task, stage, and source filters in
  `TokenUsageDashboardStore`.
- Central analytics canvas maps to KPI, AI tool, task, stage, and source rows in
  `TokenUsageDashboardSnapshot`.
- Right detail rail maps to selected Work Item detail and recent event rows.
- Primary Preferences and dashboard surfaces keep internal receiver filesystem
  paths hidden. User-facing status may expose adapter and setup state, while
  receiver path details remain developer-only diagnostics.
- The agent-status rail owns a compact token-metering setup state and two
  explicit actions: direct `Install`/`Reinstall` using the bundled helper and
  `Copy Setup Instructions` as an alternative. It must not duplicate the full
  Preferences setup form or run installation on appearance.
- Dashboard tool tabs and AI Visible toggles use the supported token-agent set
  minus the user's hidden tools. History-import rows and agent-status tool rows
  use the installed-runtime mapping instead. Running state may decorate an
  installed tool but must not decide eligibility.

Preferences should keep menu bar scanning out of primary settings unless it
becomes a clear user workflow. Preserve the existing Spill theme. Future
implementation work should change structure, scan order, and grouping before
changing color, typography, or brand treatment.
