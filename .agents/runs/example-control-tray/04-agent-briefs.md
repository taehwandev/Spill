# Agent Briefs: Example Control Tray

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer if the goal, scope, value, permission impact, or distribution impact is unclear.

## Agent A: Product

Goal:

Validate that the control tray remains compact and useful.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/example-control-tray/00-intake.md`

Output:

- `.agents/runs/example-control-tray/01-prd.md`

## Agent B: Architecture

Goal:

Define model/provider/view split and safe implementation slices.

Inputs:

- `.agents/runs/example-control-tray/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/example-control-tray/02-ard.md`
- `.agents/runs/example-control-tray/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Implement `example-control-tray-T1`.

Necessity gate:

- Confirm `.agents/runs/example-control-tray/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/SpillPanelModels.swift`

Do not edit:

- `Sources/Spill/StatusItemController.swift`

Acceptance:

- Models compile.
- Models are plain value types.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Builder

Goal:

Implement `example-control-tray-T2` after T1.

Necessity gate:

- Confirm `.agents/runs/example-control-tray/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/SystemStatusProvider.swift`
- `Sources/Spill/AIStatusProvider.swift`
- `Sources/Spill/WindowActionProvider.swift`

Do not edit:

- `Sources/Spill/SpillBarView.swift`
- `Sources/Spill/StatusItemController.swift`

Acceptance:

- Providers return placeholder models.
- No network calls.

## Agent C3: Builder

Goal:

Implement `example-control-tray-T3` after T1.

Necessity gate:

- Confirm `.agents/runs/example-control-tray/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/SpillBarView.swift`

Do not edit:

- `Sources/Spill/StatusItemController.swift`

Acceptance:

- Panel shows System, AI, Apps, and Window sections.
- Panel remains compact.

## Agent C4: Verifier

Goal:

Review all control tray changes.

Checks:

- PRD alignment
- ARD alignment
- build
- manual panel behavior
- no spacer regression

Final report:

- findings first
- verification result
- residual risks
