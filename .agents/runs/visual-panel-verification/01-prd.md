# Detailed PRD: Visual Panel Verification

## PRD Authoring Gate

Do not author this PRD until `00-intake.md` has `Decision: build` and all clarifying questions are resolved. If intent, scope, value, UI behavior, feasibility, permissions, or distribution impact is unclear, return to `00-intake.md`, ask the maintainer, and stop here.

## Summary

Add an automated panel layout smoke check that verifies Spill can open its compact panel with expected frame and content bounds. This gives future UI/provider work a repeatable gate before more visible content is added.

## Goals

- Add a workflow command for panel layout verification.
- Launch the app in smoke mode and open the panel.
- Report panel frame and content bounds from inside the app.
- Fail when the panel is not visible, off-screen, too narrow, too wide, or taller than the compact target.

## Non-goals

- No pixel screenshot comparison.
- No visual redesign.
- No new user-facing controls.
- No Accessibility or Screen Recording dependency.

## User Stories

- As a maintainer, I want a repeatable command that catches obvious panel layout regressions.
- As a contributor, I want verification that does not depend on manual screenshots or extra permissions.
- As a user, I benefit indirectly because compact layout regressions are caught earlier.

## UX Requirements

### Entry Point

The entry point is a developer workflow command:

```bash
python3 .agents/scripts/workflow.py panel-layout-smoke
```

### Layout

No layout changes are required. The existing panel should keep its current compact size.

### States

- loading: smoke script waits for app exit and reads log output.
- empty: not applicable.
- unavailable: if no panel report is produced, fail the command.
- permission required: not applicable.
- success: log contains `SPILL_PANEL_LAYOUT_OK`.
- failure: log contains missing/invalid layout report or process failure.

## Functional Requirements

1. Add a panel layout smoke mode that opens the panel and prints layout diagnostics.
2. Validate that the panel is visible.
3. Validate that the panel frame intersects the visible screen frame.
4. Validate that width and height stay within compact panel bounds.
5. Validate that content bounds match the panel content size.
6. Add a workflow command and shell script for the check.

## Acceptance Criteria

- `python3 .agents/scripts/workflow.py panel-layout-smoke` passes locally.
- Existing `runtime-smoke` and `panel-open-smoke` still pass.
- `swift build` passes.
- `swift test` passes.
- No new permissions are required.

## Metrics

- perceived latency: smoke command completes within the existing smoke timeout.
- reliability: command fails with a readable log if layout is invalid.
- resource use: no production runtime overhead.

## Rollout

- MVP: AppKit geometry-based layout smoke.
- later: screenshot or accessibility tree verification if it can be made reliable in developer environments.

## References

- `scripts/verify-panel-open-smoke.sh`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `.agents/tasks/roadmap.yml`
