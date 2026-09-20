# Quick Actions And Window Management PRD

## Document Contract

- Status: active
- Audience: product, design, engineering, and QA
- Purpose: define window action and Caffeine behavior
- Source of truth: this document owns window controls and the removal boundary for third-party menu bar actions
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md),
  [Menu Bar Surface](menu-bar-surface.md)

## Removed Menu Bar Actions

Third-party menu bar icon discovery, scanning, invocation, app activation
fallback, pinning, and detected-icon management are removed on every supported
macOS version. No version check, replacement scanner, background observer, or
permission/setup route remains for this feature. Spill's own status trigger,
status values, panel toggle, and native status menu remain supported.

Legacy scanner and pinned-item preferences are ignored; removal must not reset
unrelated preferences, token data, or window shortcuts. Existing macOS permission
grants are not revoked programmatically.

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
- Show permission state clearly and request Accessibility only when a user
  invokes window movement or explicitly opens its permission setup.
- Opening the panel or refreshing system/AI values must not request permission.
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
- Verify no scanner, detected/pinned menu action, or related permission prompt
  is reachable on any supported macOS version.
- Verify fresh and legacy settings preserve AI, system metrics, Caffeine, and
  window shortcuts; no Screen Recording request remains.
- Verify every accepted window action through its direct control and shortcut,
  when a shortcut exists.
