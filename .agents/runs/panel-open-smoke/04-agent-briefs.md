# Agent Briefs: Panel Open Smoke

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside the assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Do not add screenshot capture, private APIs, fake scanner data, or a second status item.

## Agent A: Product

Goal:

Document why panel presentation needs an automated smoke path.

Inputs:

- `.agents/runs/panel-open-smoke/00-intake.md`
- `.agents/runs/stitch-panel-shell/06-closeout.md`
- `.agents/runs/panel-fallback-launcher/06-closeout.md`

Output:

- `.agents/runs/panel-open-smoke/01-prd.md`

## Agent B: Architecture

Goal:

Define an environment-gated smoke mode and script that validates panel visibility with log markers.

Inputs:

- `.agents/runs/panel-open-smoke/01-prd.md`
- `Sources/Spill/App/AppDelegate.swift`
- `scripts/verify-runtime-smoke.sh`

Output:

- `.agents/runs/panel-open-smoke/02-ard.md`
- `.agents/runs/panel-open-smoke/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Implement the smoke-mode panel open path in `AppDelegate`.

Write scope:

- `Sources/Spill/App/AppDelegate.swift`

Do not edit:

- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Accessibility/`

Acceptance:

- `SPILL_SMOKE_OPEN_PANEL=1` opens the panel.
- Smoke panel opening does not request Accessibility.
- App logs visible or not-visible marker.

## Agent C2: Script Builder

Goal:

Add the panel-open smoke script and workflow command.

Write scope:

- `scripts/verify-panel-open-smoke.sh`
- `.agents/scripts/workflow.py`

Acceptance:

- Script validates `SPILL_PANEL_SMOKE_VISIBLE`.
- Workflow command runs the script.
- Existing runtime smoke still works.

## Agent C3: Verifier

Goal:

Run automated checks and record remaining visual verification limits.

Review scope:

- `Sources/Spill/App/AppDelegate.swift`
- `scripts/`
- `.agents/scripts/workflow.py`
- `.agents/runs/panel-open-smoke/`

Checks:

- build
- tests
- workflow verify
- runtime smoke
- panel-open smoke
- code gates

Final report:

- findings first
- verification result
- residual risks
