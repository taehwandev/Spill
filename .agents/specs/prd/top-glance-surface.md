# Standalone Spill Glance Retirement Contract

## Document Contract

- Status: retired
- Audience: product, design, engineering, QA, privacy, and release maintainers
- Purpose: preserve the removal boundary for the former always-visible Spill
  Glance widget so it is not accidentally reintroduced as an active surface
- Source of truth: this document owns the absence contract for the retired
  standalone widget
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md),
  [Menu Bar Surface](menu-bar-surface.md),
  [Compact Panel](compact-panel.md),
  [Token Metering Dashboard](token-metering/dashboard.md)

## Decision

Spill does not ship a standalone, always-visible Spill Glance panel. The former
main-process `NSPanel`/SwiftUI widget, its dedicated Preferences destination,
the token-dashboard header toggle, and its widget-only token summary have been
removed.

This retirement does not remove the word “glance” as a general product concept.
The menu-bar AI/System status, compact Spill Panel, and separate AI Token
Metering dashboard remain supported surfaces under their own contracts.

## Removal Scope

- No `Sources/Spill/Glance` runtime boundary, panel controller, feature store,
  placement store, rotation schedule, or dedicated view exists.
- `AppDelegate` does not create, start, stop, or route actions from a Glance
  panel.
- `SpillSettings` does not read or publish Glance enablement, display style,
  full-screen, rotation, or module-visibility settings.
- Preferences has no Glance sidebar route, section, controls, or localized
  labels.
- The AI Token Metering dashboard has no Glance toggle and no distributed
  settings handoff for that toggle.
- `TokenUsageDashboardStore` publishes the dashboard snapshots and the compact
  panel's `panelSummary`; it does not load or publish a separate
  `glanceSummary`.
- Dedicated Glance implementation tests are removed. A source-contract test
  guards the absence of the runtime, settings route, dashboard toggle, and
  widget-only summary.

## Compatibility And Data

- Existing local UserDefaults values for the retired widget are ignored. Spill
  does not delete them during startup or migration.
- Former saved panel-frame or display-placement metadata is likewise ignored.
- No token usage rows, local queue events, upload payloads, sync records, or
  agent-facing summaries are migrated or deleted because the widget was only a
  presentation consumer.
- No polling loop, timer, collector, database query, network request, upload,
  or helper process replaces the removed feature.

## Preserved Surfaces

- The macOS menu-bar trigger and clock-adjacent AI/System status remain owned by
  the Menu Bar Surface PRD.
- The main-process compact Spill Panel and its `panelSummary` remain owned by
  the Compact Panel and Token Metering contracts.
- The separate `Spill - AI Token Metering` dashboard helper remains available.
- Web dashboard, Private Usage Upload, usage synchronization, and local agent
  summaries are unaffected.

## Acceptance

- A fresh or upgraded launch creates no standalone Glance window or panel.
- Preferences and the AI Token Metering dashboard expose no Glance control.
- Legacy Glance defaults may remain on disk but have no reader and cannot make
  a surface appear.
- The runtime contains no `SpillGlance` owner and the dashboard store contains
  no `glanceSummary` path.
- Menu-bar AI/System status, the compact panel, and the AI Token Metering
  dashboard continue to compile and pass their existing tests.
