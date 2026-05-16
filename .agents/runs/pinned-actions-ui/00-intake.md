# Intake: Pinned Actions UI

## Request

Make stored menu bar actions feel reliable and understandable in the compact Spill Bar. Users should be able to pin detected menu bar items, see those pinned items first, get visible feedback after clicking an action, and fall back to activating the source app if a stale Accessibility item cannot be pressed.

## Why Now

The panel already detects and renders menu bar actions, but stored selections are not visible as a first-class action surface. Without pinned affordances and execution feedback, users cannot tell whether Spill remembered an item or whether an attempted action succeeded.

## Necessity

Decision: `build`

### Reasoning

Pinned actions are part of the current roadmap and reuse existing persisted selection state. The slice improves the main panel without adding private menu bar APIs, another status item, or a new permission model.

### Cost Of Skipping

Users would still need to manage saved items from Preferences and would have no compact in-panel confirmation that an action was pinned, unpinned, opened, or unavailable.

## Users

- Mac users who want a compact visible row for important menu bar extras.
- Maintainers verifying that saved item state maps to visible panel behavior.
- Contributors extending action execution beyond menu bar items.

## Scope

- Render pinned menu bar items before non-pinned detected items.
- Add compact pin and unpin controls to action tiles.
- Show success and failure feedback in the panel header.
- Preserve AXPress as the first execution path.
- Fall back to source app activation when a live AXPress target is stale.

## Non-Goals

- No private menu bar manipulation.
- No forced recovery of hidden or unavailable third-party menu bar extras.
- No new window management actions.
- No external app automation beyond public Workspace activation.
