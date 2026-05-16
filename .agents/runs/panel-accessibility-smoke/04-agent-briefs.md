# Agent Briefs: Panel Accessibility Smoke

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer before PRD authoring if the goal, scope, value, UI behavior, feasibility, permission impact, or distribution impact is unclear.
- Do not let Agent A write the PRD while `00-intake.md` is still `needs-clarification`.

## Agent A: Product

Goal:
Define the smoke check as a contributor-facing verification feature with no
end-user panel behavior changes.

PRD authoring gate:

- Confirm `.agents/runs/panel-accessibility-smoke/00-intake.md` has `Decision: build`.
- Confirm all clarifying questions are answered or explicitly marked as resolved.
- If not, ask the maintainer and stop without writing the PRD.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/panel-accessibility-smoke/00-intake.md`

Output:

- `.agents/runs/panel-accessibility-smoke/01-prd.md`

## Agent B: Architecture

Goal:
Define a smoke-only accessibility report that validates stable panel landmarks
without requiring external Accessibility permission.

Inputs:

- `.agents/runs/panel-accessibility-smoke/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/panel-accessibility-smoke/02-ard.md`
- `.agents/runs/panel-accessibility-smoke/03-task-breakdown.yml`

## Agent C1: Builder

Goal:
Implement accessibility diagnostics in the existing panel layout smoke path.

Necessity gate:

- Confirm `.agents/runs/panel-accessibility-smoke/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillFooterView.swift`
- `Sources/Spill/Panel/SpillPanelAccessibilityReport.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `scripts/verify-panel-layout-smoke.sh`
- `Tests/SpillTests/SpillPanelAccessibilityReportTests.swift`

Do not edit:

- `Sources/Spill/Accessibility/`
- `Sources/Spill/MenuBar/`
- unrelated provider code

Acceptance:

- Panel layout smoke logs `SPILL_PANEL_ACCESSIBILITY`.
- Missing required labels fail the smoke script.
- `swift test` and `panel-layout-smoke` pass.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:
Verify the new smoke gate catches missing required labels and does not change
panel behavior.

Review scope:

- Implementation files listed above.
- Run documentation and roadmap state.

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
