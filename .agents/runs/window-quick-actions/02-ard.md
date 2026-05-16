# ARD: Window Quick Actions

## Decision D1: Use The Existing Action Row

Window controls render at the front of the existing ACTIONS horizontal scroller instead of creating another vertical section.

Rationale: a separate section pushed the panel height past the compact smoke threshold. The action row already represents command surfaces, so this is the right ownership boundary.

## Decision D2: Separate Planning From AX Writes

`WindowFramePlanner` computes target frames from a plain `WindowFrameSnapshot`. `FocusedWindowController` owns Accessibility reads and writes.

Rationale: frame math is deterministic and can be unit tested without live windows or permissions.

## Decision D3: Store One Restore Frame

`WindowActionStore` stores the previous frame before successful non-restore actions. Restore clears the saved frame after a successful move.

Rationale: this is enough for a compact best-effort restore without building a window history system.

## Decision D4: Public Accessibility Only

Focused window access uses `AXFocusedWindow`, `AXPosition`, and `AXSize`. The implementation does not use private window server APIs.

## Decision D5: State Is Refreshed On Panel Show

The panel refreshes window actions when it opens so missing permission and focused-window availability are reflected before the user clicks.

## Verification

- Unit tests cover left, right, center, maximize, next display, and restore frame planning.
- Smoke checks confirm the panel remains visible and compact.
