# Menu Bar Surface PRD

## Document Contract

- Status: active
- Audience: product, design, engineering, and QA
- Purpose: define Spill's own menu bar trigger and glance surfaces
- Source of truth: this document owns Spill-created menu bar status items
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md),
  [Quick Actions And Window Management](quick-actions-and-window-management.md)

## Boundary

This document owns Spill's trigger and status values. Detection and invocation
of third-party menu bar items belong to the quick-actions PRD.

## Requirements

- A small fixed-width Spill icon appears in the menu bar as the primary Main
  item. The droplet remains the default trigger mark, and users may choose the
  symbolized Spill S mark as an alternate trigger mark.
- By default, enabled menu bar values render in one horizontal status item with
  the Spill trigger, preserving the classic compact menu bar presentation.
- Compact rendering and functional group splitting are independent Preferences
  options. Users may opt into tighter icon/value rendering, separate Main/System/AI
  menu bar items, both, or neither.
- In split mode, the groups are:
  - Main: Spill trigger plus optional Caffeine state.
  - System: CPU, memory, and optional network glance values.
  - AI: local token/AI glance value.
- CPU, memory, and Network each expose an independent Off, Text, or Chart mode.
  Text shows the current numeric value, while Chart replaces that value with a
  framed history chart that includes a visible background, guide, and area fill.
- CPU, memory, and optional Network charts support both horizontal and vertical
  clock-area layouts.
- Network is available as a default-off clock-area option. Text mode shows its
  receive and upload rates; Chart mode uses distinct RX/TX traces with shared
  recent-peak scaling so low traffic remains visually meaningful.
- Menu bar graphs reuse the system status store history and refresh cadence;
  they do not create independent timers, probes, or permission requirements.
- Existing global Text/Chart preferences migrate to each graph-capable metric;
  new installations keep CPU and memory on Text while Network remains Off.
- Caffeine is part of the main menu bar surface, not a standalone status group.
  When compact split mode is enabled, it may appear as a small badge or active
  state on the Spill trigger, with detailed remaining time available in tooltip
  or panel UI.
- Left click toggles Spill Panel.
- Right click or Control-click opens a native menu with:
  - Show/Hide Spill Panel
  - Open Spill - AI Token Metering
  - Refresh
  - Check for Updates
  - Preferences
  - Quit
- No spacer-based layout manipulation.

## Acceptance

- The default menu bar presentation remains a single horizontal item unless the
  user enables split groups.
- In split mode, the Main trigger remains small and visually distinct from
  optional System and AI status values.
- Compact icon/value rendering never becomes the default solely because the menu
  bar is crowded; it is controlled by the compact display option.
- Caffeine state does not consume a standalone status group.
- Off, Text, and Chart are independently selectable for CPU, memory, and
  Network. Text and Chart are mutually exclusive within each glance chip.
- Chart mode has a visible frame and guide and remains legible in both horizontal
  and vertical layouts.
- Network remains disabled by default, can be enabled from clock-area status
  Preferences, and distinguishes receive from upload in both text and chart modes.
- Accessibility labels and tooltips communicate metric values without relying
  on graph shape or color alone.
- Local token usage appears inside the panel AI section.
- No invisible, spacer, or oversized status items are created.
- The app remains usable when the menu bar is crowded, subject to macOS status
  item limitations.

## Verification

- Verify single-item and split-item modes independently from compact rendering.
- Verify graph-capable settings migrate without enabling Network by default.
- Verify status chips reuse existing provider history and do not add timers.
