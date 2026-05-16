# Agent Briefs: Pinned Actions UI

## Coordination

Do not add private menu bar APIs, a second status item, or broad normal menu bar scanning. Keep the panel compact and preserve existing scanner behavior.

## Product Architect Brief

Define the slice around persisted menu bar selections becoming visible pinned actions. Confirm that `selectedItemKeys` remains the persistence source and that focused-window actions stay out of scope.

Deliverables:

- Approved intake, PRD, and ARD.
- Task breakdown with verification commands.
- Non-goals covering private APIs and window actions.

## Builder Brief

Implement pin-aware rendering inside `SpillBarView` and enrich menu bar actions with the source bundle identifier.

Deliverables:

- `SpillActionKind.menuBarItem` carries the source bundle identifier.
- `MenuBarActionAdapter` maps and recovers source bundle identifiers.
- `SpillBarView` renders pinned actions first.
- `SpillActionButton` has a compact pin overlay.
- Execution feedback appears in the header.
- App activation fallback uses public Workspace APIs.

Constraints:

- Disabled execution must not block pin and unpin.
- Keep the action row within the panel layout smoke constraints.
- Do not move scanner ownership out of `AXMenuBarItemScanner`.

## Verifier Brief

Run deterministic checks and record residual manual visual risk.

Commands:

- `swift test`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py verify`
- `git diff --check`

Manual check:

- Open the panel in a real session and verify pin overlay placement, header feedback, and source app fallback behavior with live menu bar items.
