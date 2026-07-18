# Quick Actions And Window Management PRD

## Document Contract

- Status: active
- Audience: product, design, engineering, and QA
- Purpose: define pinned, detected, and window action behavior
- Source of truth: this document owns third-party menu bar actions and window controls
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md),
  [Menu Bar Surface](menu-bar-surface.md)

## Pinned Actions And Pin Management

Requirements:

- Users can pin detected menu bar items or apps.
- Pinned actions show app icon and short label.
- MVP compact panel shows up to 8 pinned actions.
- Pin/unpin is available directly from visible detected action tiles.
- Preferences should not expose a separate detected-icon management surface
  unless it becomes a clear user-facing workflow. Pin/unpin should remain
  available directly from visible detected action tiles.
- Click order:
  1. Try stored Accessibility action if available.
  2. Try app activation/open fallback.
  3. Show failure state with retry/refresh affordance.

Acceptance:

- Clicking an action never silently fails.
- Users can remove pinned actions.
- Users can remove pinned actions from the direct action surface.
- If more than 8 actions are pinned, the compact panel shows the first 8 and
  keeps overflow behavior predictable without requiring a separate Settings
  workflow.

## Detected Menu Bar Items

Requirements:

- Keep Accessibility scanner best-effort.
- Scan asynchronously.
- Do not promise complete coverage.
- Display detected items as candidates for pinning.
- Explain that some third-party menu bar items cannot be detected or invoked
  through public APIs.

Acceptance:

- Scanner does not freeze UI.
- Scanner message explains limitations.

## Window Quick Actions

Initial actions:

- Left half
- Right half
- Center
- Maximize
- Next display
- Restore previous frame

Requirements:

- Use Accessibility APIs for active window movement.
- Show permission state clearly.
- Keep UI to one compact row.

Acceptance:

- Works on normal resizable windows.
- Fails gracefully on non-resizable/system windows.

## Open Coverage Decisions

The current implementation and README describe behavior not normatively defined
by the former root PRD. Product review must accept, revise, defer, or remove:

- Top and bottom halves, four corner placements, and previous-display movement.
- Global and per-window-action keyboard shortcuts.
- Sleep Guard/Caffeine durations, expiry, cancellation, and display-awake behavior.

## Verification

- Verify success, unavailable, permission-required, unsupported, and failure results.
- Verify scanner work remains asynchronous and best-effort.
- Verify every accepted window action through its direct control and shortcut,
  when a shortcut exists.
