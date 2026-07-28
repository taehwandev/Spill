# Top Glance Surface PRD

## Document Contract

- Status: active
- Audience: product, design, engineering, QA, privacy, and release maintainers
- Purpose: define the always-visible, top-center Spill Glance surface
- Source of truth: this document owns Spill Glance placement, modules,
  interaction, configuration, and acceptance
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md),
  [AI Status](ai-status.md), [Token Metering Dashboard](token-metering/dashboard.md),
  [Menu Bar Surface](menu-bar-surface.md)

## Goal

Spill Glance makes the smallest useful slice of current-day AI usage visible without
requiring the user to open the compact panel or the local token dashboard.

The surface should feel like one native macOS Control Center glass bar:
lightweight, translucent, rounded, content-hugging, and subordinate to the menu
bar. It is a glance and entry point, not a second dashboard.

## MVP Requirements

- Spill Glance appears in the main app process as exactly one horizontal row.
  On first launch it is centered at the top of the primary display; Spill does
  not clone the row onto every connected display.
- The row stays fully inside `NSScreen.visibleFrame`, below the macOS menu bar,
  and never covers the notch or status items. Its default resting position
  leaves a 10-point visual gap below the visible frame's top edge.
- The surface is nonactivating. Showing it and clicking a module must not make
  Spill the key or main app window.
- The content row is no taller than 34 points.
- All enabled modules render inside one rounded glass capsule with subtle
  internal separators. There is no stack of independent floating capsules,
  large card, title bar, sidebar, or detail rail.
- Clicking any usage or Work Type segment opens the existing local
  `Spill - AI Token Metering` dashboard through the existing launcher path.
- A trailing settings segment remains inside the same grouped surface and opens
  the dedicated Spill Glance Preferences destination directly.
- The complete row is draggable across connected displays. Dragging selects the
  display under the absolute pointer, constrains the panel to that display's
  visible frame, and tracks the pointer without coordinate feedback, jitter, or
  redraw trails.
- Spill restores the last valid position on the next launch when its display is
  connected. If that display is unavailable, the single row temporarily falls
  back to the current primary display; this fallback does not overwrite the
  saved external-display position, so reconnecting the display can restore it.
- Spill Glance is enabled by default with only All Today, Work Type, and the
  trailing settings action visible. A dedicated **Spill Glance** destination in
  the Preferences sidebar lets users disable the entire surface or independently
  add the Codex, Claude, and Antigravity segments, and choose whether Work Type
  rotates, without having to infer that it belongs under Menu Bar.
- All Today, Work Type, and the trailing settings action are fixed while the
  surface is enabled. Disabling the master switch hides the surface.
- Module order is fixed for MVP so configuration remains a set of simple
  visibility choices. Drag reordering is future scope.

## Token Strip Segments

The default order is:

1. **All Today**
   - Shows the current-day total using the selected input accounting scope.
2. **Codex, Claude, and Antigravity**
   - Each tool has its own compact current-day token segment.
   - Each segment can be hidden independently in Spill Glance Preferences.
   - The visible segment uses the tool's established dashboard color plus its
     icon and compact value. It does not spend width repeating the full tool
     name; the full name remains available to accessibility.
   - A tool with no current-day row shows a compact no-data value instead of
     disappearing or implying current activity.
3. **Work Type**
   - Shows each current-day task category with its compact token total.
   - Rotation defaults on and advances through categories in descending usage
     order at a three-second interval.
   - Users can turn rotation off in Spill Glance Preferences. The segment then
     keeps the highest-usage Work Type and its token total visible.
   - Known long category labels use compact semantic names. Long custom safe
     slugs use their initials rather than rendering a clipped ellipsis.
   - If there is no task data, it shows a compact no-data state.
   - It uses the current-day task rows from
     `TokenUsageDashboardStore.glanceSummary`.
4. **Settings**
   - Shows a compact trailing gear action.
   - A tap opens the existing dedicated Spill Glance Preferences destination.

The Work Type segment is intentionally category-based. Spill does not inspect
prompts, commands, transcripts, repository names, file paths, or arbitrary task
content to invent a semantic current-task title.

## Settings Impact Map

| Contract | Decision |
| --- | --- |
| Persistence owner | Main-process `SpillSettings` for visibility plus a local Glance frame store for the last window position |
| Defaults and migration | `glanceEnabled = true`; `glanceWorkRotationEnabled = true` when absent so existing installations preserve rolling; Codex, Claude, and Antigravity off until selected; All Today and Work Type fixed; legacy `aiStatus`/`topTask`/`todayTokens` selections migrate to all three optional tools; unknown and duplicate values normalize deterministically |
| Reading processes | Main Spill process only |
| Propagation transport | In-process `@Published` updates; no distributed notification is required because no helper process reads these settings |
| Refresh trigger | `SpillSettings` publisher updates rebuild Glance state, then the AppKit bridge consumes the committed presentation on the next main-queue turn |
| Expected latency | Within the next display frame; never delayed until the three-second Work rotation tick |
| Preferences | Affected: a dedicated Spill Glance sidebar destination owns the enable, Work Type rotation, and module visibility controls |
| Spill Glance | Affected: it reads the master, Work Type rotation, and optional-tool visibility settings in process |
| Main compact Spill Panel | Not applicable to Glance settings: its existing AI strip and status cards remain unchanged. The separate rounded-backdrop clipping correction does not read Glance settings |
| Separate AI Token Metering helper | Not applicable: it neither reads nor renders Glance settings |
| Clock-adjacent AI menu bar glance | Not applicable: existing menu bar AI settings and layout remain independent |
| Web dashboard, Private Usage Upload, sync payloads, agent summaries | Not applicable: Glance settings do not change stored usage data, upload policy, payloads, or summaries |

## Performance And Privacy

- `TokenUsageDashboardStore` publishes two distinct presentation companions:
  the existing `panelSummary` remains filtered by the dashboard's hidden-tool
  preference, while `glanceSummary` is an unfiltered current-day summary across
  every supported tool for Spill Glance.
- Both summaries refresh through the existing event-driven store path. They
  rebuild when token usage store events arrive and when macOS reports a
  calendar-day change, system-clock change, or timezone change, so "today"
  rolls over correctly even when no new token event arrives.
- When rotation is enabled and more than one Work Type exists, it may use one
  bounded SwiftUI presentation schedule to rotate already-loaded Work Type
  display values. It must not add a collector polling loop, process probe,
  database watcher, network request, token collector, upload attempt, or cloud
  dependency.
- It must not inspect content to derive labels.
- Glance settings are presentation-only local preferences and are not part of
  token usage events or private usage upload payloads.

## Accessibility

- The grouped bar exposes a useful accessibility label that includes each
  visible module label and current value.
- The row exposes an action hint for opening the local AI token dashboard.
- The trailing settings segment exposes a named accessibility action for
  opening Spill Glance Preferences.
- State may use tint as decoration, but running, ready, and no-data states must
  remain understandable from text.

## Non-Goals

- Replacing the menu bar trigger.
- Moving, hiding, cloning, or spacing third-party menu bar items.
- Showing shortcuts, arbitrary apps, media controls, Calendar, Mail, or custom
  widgets in MVP.
- A second dashboard, chart canvas, or two-line expanded mode.
- Module reordering.
- Screen capture, notch overlays, or private window-server APIs.

## Acceptance

- A fresh settings store enables Glance with only fixed All Today and Work Type
  segments; Codex, Claude, and Antigravity appear only after the user enables
  them.
- Disabling one tool removes only that tool segment. Fixed segments cannot be
  toggled off, and disabling the surface hides the panel.
- Work Type rotation defaults on. Turning it off immediately fixes the
  highest-usage Work Type and compact token total without restarting,
  reopening, manually refreshing, waiting for the next rotation tick, moving
  the Glance frame, or changing any other AI surface.
- The row is at most 34 points high, horizontally content-sized, centered in
  the selected screen's visible frame on first launch, and positioned below its
  top edge with a 10-point default gap.
- Dragging any part of the grouped bar moves it without opening the dashboard,
  follows the screen pointer without jitter or residual redraw trails, clamps it
  inside the visible frame, and persists the final valid frame.
- Only one Glance panel exists across all displays. It can be dragged from a
  built-in display to a connected external display. Disconnecting the saved
  external display falls back to the current primary display, while reconnecting
  it restores the saved external-display position without creating a duplicate.
- The complete default strip, including its settings action, remains
  content-sized and under the compact width budget defined by layout tests.
- The panel cannot become key or main and does not activate Spill.
- Clicking usage or Work Type segments uses the existing dashboard open action.
  Clicking the settings segment opens the existing `glance` Preferences tab.
- Token and Work Type changes appear through the event-driven `glanceSummary`
  and settings publishers. Current-day values also rebuild on calendar-day,
  system-clock, and timezone notifications. Work display values combine compact
  labels and token totals, and rotate through one presentation-only SwiftUI
  schedule only when enabled, without a new polling timer, database watcher,
  collector, network client, process scan, or upload path.
- English, Korean, and Japanese Preferences labels are available.
- Preferences exposes a clearly labeled Spill Glance sidebar destination that
  opens the master and per-module controls directly.

## Verification

- Unit-test settings defaults, persistence, normalization, module toggles, and
  the default-on Work Type rotation preference.
- Unit-test Glance state derivation from fixture `glanceSummary` snapshots,
  including tools hidden from `panelSummary`.
- Unit-test event, calendar-day, system-clock, and timezone invalidation of both
  dashboard summary companions without a polling fallback.
- Unit-test frame placement for multiple screen frames, display connection and
  disconnection, saved-display restoration, and safe-area sizes.
- Unit-test drag translation, visible-frame clamping, and frame persistence.
- Source-contract test the nonactivating panel behavior, settings routing,
  grouped glass composition, committed-state presentation delivery,
  layout-only frame invalidation, bounded Work presentation schedule, and
  absence of collector timers or network work in the Glance boundary.
- Package and launch the app, capture the top-center surface, and visually
  verify height, content hugging, one grouped capsule, internal separation,
  drag behavior, absence of ellipsized labels, and menu bar clearance in both
  light and dark appearance.
