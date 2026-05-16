# Agent Briefs: Window Quick Actions

## Coordination

Keep the implementation public-API only. Do not use private window server APIs or add another menu bar item.

## Builder Brief

Implement window quick actions with a pure planner, an AX execution layer, and compact rendering in the existing ACTIONS row.

Deliverables:

- `WindowFramePlanner` and `WindowFrameSnapshot`.
- `WindowActionStore` and `FocusedWindowController`.
- AX focused window, position, and size read/write support.
- Window action buttons inside `SpillBarView`.
- Frame planner tests.

Constraints:

- Preserve panel layout smoke limits.
- Store only one best-effort restore frame.
- Disabled states should explain permission, no focused window, one display, or no restore frame.

## Verifier Brief

Run:

- `swift test`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py verify`
- `git diff --check`

Manual follow-up:

- With Accessibility permission granted, focus a normal app window and test left, right, center, maximize, next display on multi-display setups, and restore.
