# Agent Briefs: Single Trigger Reset

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer if the goal, scope, value, permission impact, or distribution impact is unclear.

## Agent A: Product

Goal:

Confirm that this slice only resets the menu bar entry point.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/single-trigger-reset/00-intake.md`

Output:

- `.agents/runs/single-trigger-reset/01-prd.md`

## Agent B: Architecture

Goal:

Define the single-status-item implementation boundary.

Inputs:

- `.agents/runs/single-trigger-reset/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/single-trigger-reset/02-ard.md`
- `.agents/runs/single-trigger-reset/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Remove spacer status item behavior and keep one visible trigger.

Necessity gate:

- Confirm `.agents/runs/single-trigger-reset/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/MenuBar/MenuBarNotchGeometry.swift`
- `.agents/runs/single-trigger-reset/`

Do not edit:

- `Sources/Spill/Panel/`
- `Sources/Spill/Preferences/`
- `Package.swift`

Acceptance:

- One `NSStatusItem` is created.
- No spacer logic remains in `StatusItemController`.
- `swift build` passes.
- `code-gates` passes.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Review the reset for architecture compliance and regressions.

Review scope:

- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/MenuBar/MenuBarNotchGeometry.swift`
- `.agents/runs/single-trigger-reset/`

Checks:

- PRD alignment
- ARD alignment
- build
- code-gates
- manual trigger behavior

Final report:

- findings first
- verification result
- residual risks
