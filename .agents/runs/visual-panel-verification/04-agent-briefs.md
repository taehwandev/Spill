# Agent Briefs: Visual Panel Verification

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer before PRD authoring if the goal, scope, value, UI behavior, feasibility, permission impact, or distribution impact is unclear.
- Do not let Agent A write the PRD while `00-intake.md` is still `needs-clarification`.

## Agent A: Product

Goal: Confirm the verification slice catches compact panel geometry regressions without changing product UI.

PRD authoring gate:

- Confirm `.agents/runs/visual-panel-verification/00-intake.md` has `Decision: build`.
- Confirm all clarifying questions are answered or explicitly marked as resolved.
- If not, ask the maintainer and stop without writing the PRD.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/visual-panel-verification/00-intake.md`

Output:

- `.agents/runs/visual-panel-verification/01-prd.md`

## Agent B: Architecture

Goal: Define smoke-only layout reporting and workflow wiring.

Inputs:

- `.agents/runs/visual-panel-verification/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/visual-panel-verification/02-ard.md`
- `.agents/runs/visual-panel-verification/03-task-breakdown.yml`

## Agent C1: Builder

Goal: Implement panel layout smoke reporting and workflow command.

Necessity gate:

- Confirm `.agents/runs/visual-panel-verification/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `scripts/verify-panel-layout-smoke.sh`
- `.agents/scripts/workflow.py`
- `.agents/README.md`

Do not edit:

- Menu bar trigger architecture.
- Provider models or provider reads.
- Panel visual design unless required for the smoke report.

Acceptance:

- `panel-layout-smoke` passes.
- Existing runtime and panel-open smoke checks still pass.
- No new permissions are required.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal: Verify smoke markers, workflow command, and documentation.

Review scope:

- Smoke layout report.
- Shell script.
- Workflow command.
- Run closeout.

Checks:

- PRD alignment
- ARD alignment
- build
- manual behavior
- permission states

Final report:

- findings first
- verification result
- residual risks
