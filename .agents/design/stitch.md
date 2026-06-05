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

## Current Token Metering Dashboard Mapping

`Spill Pro: Structured Token Dashboard` is the current layout reference for
the local token metering dashboard.

- Top header maps to `TokenMeteringDashboardView.header`.
- Left filter rail maps to the period/tool filters and future task, stage, and
  source filters in `TokenUsageDashboardStore`.
- Central analytics canvas maps to KPI, AI tool, task, stage, and source rows in
  `TokenUsageDashboardSnapshot`.
- Right detail rail maps to selected session/run detail and recent event rows.
- Local receiver status tiles map to local inbox, optional HTTP bridge, and
  on-demand adapter state in Preferences and dashboard diagnostics.

Preserve the existing Spill theme. Future implementation work should change
structure, scan order, and grouping before changing color, typography, or brand
treatment.
