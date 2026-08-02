# Top Glance Surface PRD

## Document Contract

- Status: active
- Audience: product, design, engineering, QA, privacy, and release maintainers
- Purpose: define the always-visible, display-relative Spill Glance surface
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

- Spill Glance appears in the main app process as exactly one grouped horizontal
  surface. On first launch it is centered at the top of the primary display;
  Spill does not clone the surface onto every connected display.
- The surface stays fully inside `NSScreen.visibleFrame`, below the macOS menu bar,
  and never covers the notch or status items. Its default resting position
  leaves a 10-point visual gap below the visible frame's top edge.
- The surface is nonactivating. Showing it and clicking a module must not make
  Spill the key or main app window.
- The content row is no taller than 34 points and keeps fixed readable
  typography. A vertical rail is not offered because it consumes wall width
  without increasing the amount of useful glance information.
- All enabled modules render inside one rounded glass group with subtle
  internal separators. There is no stack of independent floating capsules,
  large card, title bar, sidebar, or detail rail.
- Clicking any usage or Work Type segment opens the existing local
  `Spill - AI Token Metering` dashboard through the existing launcher path.
- A trailing settings segment remains inside the same grouped surface and opens
  the dedicated Spill Glance Preferences destination directly.
- The complete surface is draggable across connected displays. Dragging selects the
  display under the absolute pointer, constrains the panel to that display's
  visible frame, and tracks the pointer without coordinate feedback, jitter, or
  redraw trails.
- Spill persists placement as display identity plus visible-frame-relative
  semantics, not only as an absolute desktop rectangle. Positions near an edge
  keep that edge or corner with a fixed inset, so right-bottom remains
  right-bottom after a display resolution or work-area change. Free positions
  preserve normalized X/Y ratios inside the display's `visibleFrame`.
- Spill restores the last valid position on the next launch when its display is
  connected. If that display is unavailable, the single surface temporarily falls
  back to the current primary display; this fallback does not overwrite the
  saved external-display position, so reconnecting the display can restore it.
- Spill Glance is **disabled by default**: an always-visible strip must be an
  explicit opt-in, not something a fresh install puts on screen. When enabled
  it starts with only All Today, Work Type, and the trailing settings action
  visible. A dedicated **Spill Glance** destination in the Preferences sidebar
  lets users enable or disable the entire surface, choose **All** or
  **Ticker** display style, turn **Reactive View** on or off, independently
  add the Codex, Claude, and Antigravity segments, choose whether Work Type
  contributes all current-day categories to the rotation queue, and opt into
  visibility in native full-screen Spaces, without having to infer that it
  belongs under Menu Bar.
- The token metering dashboard header carries a Spill Glance on/off toggle so
  users can flip the strip from where they watch usage. The toggle writes the
  same shared setting; the dashboard helper and the main process stay in sync
  through the existing distributed settings-change notification, and the strip
  appears or disappears immediately without a restart.
- **All** keeps every selected segment visible as the current compact row.
  **Ticker** keeps one fixed-width slot. The display style chooses the layout;
  **Reactive View** chooses what drives the rotation, and applies to both.
- **Reactive View** defaults on. Only a module whose value just changed takes a
  slot, each change holds the slot for a fixed dwell, and a module that keeps
  changing inside its own dwell updates that slot in place rather than queueing
  another one. When nothing has changed recently the Ticker rests on All Today
  and the All layout's Work slot rests on the highest-usage Work Type.
- With Reactive View off, rotation falls back to the fixed schedule: Ticker
  advances through All Today, every enabled AI tool, and one Work Type slot in
  that order, and each return to the Work slot advances to the next selected
  Work Type. The settings action stays visible and outside the rotating slot in
  both modes.
- The horizontal surface remains freely draggable along both axes and across
  connected displays, so users may place it at the top, bottom, or a free
  position without changing orientation.
- The panel joins normal Spaces but is hidden from native full-screen Spaces by
  default. Users may explicitly enable full-screen visibility; changing this
  option takes effect immediately without recreating the feature store.
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
   - Rotation defaults on. With Reactive View on it surfaces the category whose
     total just changed and then settles back to the highest-usage category;
     with Reactive View off it advances through categories in descending usage
     order at a five-second interval.
   - Users can turn rotation off in Spill Glance Preferences. The segment then
     keeps the highest-usage Work Type and its token total visible, and Work
     never enters the reactive queue.
   - Known long category labels use compact semantic names. Long custom safe
     slugs use their initials rather than rendering a clipped ellipsis.
   - Value typography uses a fixed readable point size. The layout may reserve
     enough width for bounded compact values, but must not dynamically scale the
     font down as content or display geometry changes.
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
| Persistence owner | Main-process `SpillSettings` for visibility, display style, full-screen policy, and module behavior plus a local Glance placement store for display-relative placement |
| Defaults and migration | `glanceEnabled = false` (opt-in surface); `glanceWorkRotationEnabled = true`; `glanceReactiveRotationEnabled = true`; `glanceDisplayStyle = all`; `glanceShowInFullScreen = false`; missing or invalid display style defaults to All; the unreleased orientation and wall-side preferences are ignored after vertical mode removal; Codex, Claude, and Antigravity stay off until selected; All Today and Work Type remain fixed; legacy absolute frames migrate to display-relative placement when their saved display is available; legacy `aiStatus`/`topTask`/`todayTokens` selections migrate to all three optional tools; unknown and duplicate values normalize deterministically |
| Reading processes | Main Spill process only |
| Propagation transport | In-process `@Published` updates; no distributed notification is required because no helper process reads these settings |
| Refresh trigger | `SpillSettings` publisher updates rebuild Glance state, then the AppKit bridge consumes the committed presentation on the next main-queue turn; module or display-style changes reapply geometry, while full-screen policy updates the panel collection behavior |
| Expected latency | Within the next display frame; never delayed until the five-second Work rotation tick |
| Preferences | Affected: a dedicated Spill Glance sidebar destination owns enable, All/Ticker style, Reactive View, native full-screen visibility, Work Type rotation, and module visibility controls |
| Spill Glance | Affected: it reads the master, display style, Reactive View, native full-screen visibility, Work Type rotation, and optional-tool visibility settings in process |
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
- Rotation uses at most one bounded SwiftUI presentation schedule over
  already-loaded display values, whichever rotation model is active. With
  Reactive View off the schedule is periodic: Ticker gives every selected module
  one global queue slot, and each completed global cycle advances the value
  inside the Work slot, which keeps Work proportional without nesting a second
  schedule. With Reactive View on the schedule is the explicit list of queued
  change boundaries, so the surface stops redrawing once the queue drains. The
  queue is bounded to one pending slot per module and is derived only from
  differences between consecutive current-day summaries. Neither model may add a
  collector polling loop, process probe, database watcher, network request,
  token collector, upload attempt, or cloud dependency.
- It must not inspect content to derive labels.
- Glance settings are presentation-only local preferences and are not part of
  token usage events or private usage upload payloads.

## Accessibility

- The grouped bar exposes a useful accessibility label that includes each
  visible module label and current value.
- The grouped surface exposes an action hint for opening the local AI token dashboard.
- The trailing settings segment exposes a named accessibility action for
  opening Spill Glance Preferences.
- State may use tint as decoration, but running, ready, and no-data states must
  remain understandable from text.

## Non-Goals

- Replacing the menu bar trigger.
- Moving, hiding, cloning, or spacing third-party menu bar items.
- Showing shortcuts, arbitrary apps, media controls, Calendar, Mail, or custom
  widgets in MVP.
- A second dashboard, chart canvas, or expanded multi-line data card.
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
- All display style shows every selected module in one row. Ticker style keeps a
  stable compact width and rotates All Today, enabled AI tools, and one Work
  slot. With Reactive View off the Work slot advances to its next value only
  after the full global queue completes. Switching styles updates within the
  next display frame and never moves the saved placement.
- Reactive View defaults on. Turning it on or off immediately switches rotation
  models without restarting, reopening, manually refreshing, moving the Glance
  frame, or changing any other AI surface. Reconfiguring the surface — adding or
  removing a module, switching display style, or toggling either rotation
  preference — clears the pending change queue rather than replaying the
  resulting value differences as if they were usage.
- The default row is at most 34 points high, horizontally content-sized, centered in
  the selected screen's visible frame on first launch, and positioned below its
  top edge with a 10-point default gap.
- Dragging any part of the grouped surface moves it without opening the dashboard,
  follows the screen pointer without jitter or residual redraw trails, clamps it
  inside the visible frame, and persists the final valid display-relative
  placement.
- A right-bottom, left-top, or other edge-anchored position keeps the same edge
  and inset when its display size or visible frame changes. A free position keeps
  its normalized visible-frame ratio. Disconnect fallback does not overwrite the
  preferred display identity or placement.
- The horizontal row can be placed near the top or bottom edge or at a free
  visible-frame-relative position. A display-size change preserves semantic
  edge anchors and normalized free positions without changing typography.
- Only one Glance panel exists across all displays. It can be dragged from a
  built-in display to a connected external display. Disconnecting the saved
  external display falls back to the current primary display, while reconnecting
  it restores the saved external-display position without creating a duplicate.
- The complete default surface, including its settings action, remains
  content-sized and under the compact width budget defined by layout tests.
- All style keeps short visible tool labels, established tool colors, enough
  fixed cell width, and stronger internal separators so adjacent values remain
  distinguishable without dynamic font scaling. Each stable width must contain
  the icon, label, bounded compact value, internal gaps, and horizontal padding
  at the fixed font sizes; content must never paint across a separator or into
  an adjacent cell.
- The panel cannot become key or main and does not activate Spill.
- The panel is absent from native full-screen Spaces by default. Enabling the
  full-screen option makes it an auxiliary full-screen panel immediately;
  disabling the option explicitly excludes it from those Spaces and removes it
  without an app restart, even though it continues to join ordinary Spaces.
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
- Glance token and Work values keep their fixed readable font size in both All
  and Ticker styles; layout never uses minimum-scale font reduction. Layout
  tests measure representative maximum compact strings against the same fixed
  typography and require every All and Ticker budget to contain them.

## Verification

- Unit-test settings defaults, persistence, normalization, module toggles, and
  the default-on Work Type rotation preference.
- Unit-test Glance state derivation from fixture `glanceSummary` snapshots,
  including tools hidden from `panelSummary`.
- Unit-test event, calendar-day, system-clock, and timezone invalidation of both
  dashboard summary companions without a polling fallback.
- Unit-test semantic placement for multiple screen frames, resolution changes,
  edge/corner anchors, free normalized positions, display connection and
  disconnection, legacy-frame migration, saved-display restoration, top/bottom
  edge attachment, and safe-area sizes.
- Unit-test drag translation, visible-frame clamping, and frame persistence.
- Source-contract test the nonactivating panel behavior, settings routing,
  grouped glass composition, committed-state presentation delivery,
  layout-only frame invalidation, conditional full-screen collection behavior,
  one bounded five-second presentation schedule, one-slot Work weighting,
  stable-identity crossfading fixed-width Ticker transitions, the occlusion
  pause on the rotation schedule, and
  absence of collector timers or network work in the Glance boundary.
- Package and launch the app, capture the top-center surface, and visually
  verify horizontal height, top and bottom placement, All and fixed-width Ticker
  styles, one grouped continuous glass surface, internal separation, drag
  behavior, fixed readable typography without ellipsized labels, full-screen
  default hiding, and menu bar clearance in both light and dark appearance.
