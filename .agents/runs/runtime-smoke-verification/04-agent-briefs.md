# Agent Briefs: Runtime Smoke Verification

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer if the goal, scope, value, permission impact, or distribution impact is unclear.

## Agent A: Product

Goal:

Define the missing runtime verification layer.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/runtime-smoke-verification/00-intake.md`

Output:

- `.agents/runs/runtime-smoke-verification/01-prd.md`

## Agent B: Architecture

Goal:

Define smoke mode and workflow boundaries.

Inputs:

- `.agents/runs/runtime-smoke-verification/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/runtime-smoke-verification/02-ard.md`
- `.agents/runs/runtime-smoke-verification/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Add smoke mode, smoke script, and workflow/docs integration.

Necessity gate:

- Confirm `.agents/runs/runtime-smoke-verification/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/App/AppDelegate.swift`
- `scripts/verify-runtime-smoke.sh`
- `.agents/scripts/workflow.py`
- `.agents/runs/runtime-smoke-verification/`
- `README.md`
- `.agents/`

Do not edit:

- `Sources/Spill/MenuBar/`
- `Sources/Spill/Panel/`

Acceptance:

- Runtime smoke command passes.
- Default verify command still passes.
- Normal startup path is gated away from smoke mode only.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Review the smoke test for cleanup, failure reporting, and normal behavior safety.

Review scope:

- smoke mode code
- smoke script
- workflow docs

Checks:

- build
- runtime smoke
- docs gates
- language gate
- no normal startup regression

Final report:

- findings first
- verification result
- residual risks
