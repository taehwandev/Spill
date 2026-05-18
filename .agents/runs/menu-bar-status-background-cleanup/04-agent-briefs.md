# Agent Briefs: Menu Bar Status Background Cleanup

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Confirm `.agents/runs/menu-bar-status-background-cleanup/00-intake.md` has `Decision: build`.
- This slice changes the menu bar status item, not the compact panel. The Stitch panel mapping is unchanged.

## Agent A: Product

Goal:

Document the maintainer request as a narrow visual cleanup for the clock-area menu bar status UI.

PRD authoring gate:

- Confirm `00-intake.md` has `Decision: build`.
- Confirm there are no blocking clarifying questions.

Inputs:

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/design/stitch.md`
- `.agents/runs/menu-bar-status-background-cleanup/00-intake.md`

Output:

- `.agents/runs/menu-bar-status-background-cleanup/01-prd.md`

## Agent B: Architecture

Goal:

Keep the architecture limited to the existing AppKit status item renderer.

Inputs:

- `.agents/runs/menu-bar-status-background-cleanup/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/menu-bar-status-background-cleanup/02-ard.md`
- `.agents/runs/menu-bar-status-background-cleanup/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Remove the rounded colored backgrounds from menu bar status chips while preserving segment geometry and click behavior.

Necessity gate:

- Confirm `00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Tests/SpillTests/MenuBarStatusContentViewTests.swift`

Do not edit:

- `Sources/Spill/Panel`
- `Sources/Spill/Providers`
- `Sources/Spill/Settings`

Acceptance:

- Menu bar status chip subviews do not draw layer backgrounds.
- Existing hit-testing behavior remains covered.
- `swift test` and `swift build` pass.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Verify the visual cleanup does not regress the status item build or hit testing.

Review scope:

- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Tests/SpillTests/MenuBarStatusContentViewTests.swift`

Checks:

- PRD alignment
- ARD alignment
- `swift test`
- `swift build`
- manual app launch when feasible

Final report:

- findings first
- verification result
- residual risks
