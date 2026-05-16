# Agent Briefs: Panel Content UI Polish

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside the assigned scope.
- Keep the app buildable.
- The maintainer said to ignore the left-side Stitch UI and use content structure only.
- Do not commit API keys, MCP config, or Stitch access tokens.

## Agent A: Product

Goal:

Document the content-based UI polish requirements.

PRD authoring gate:

- Confirm `00-intake.md` has `Decision: build`.
- Confirm there are no unresolved blocking questions.

Inputs:

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/design/stitch.md`
- Stitch screen `Spill Multi-Widget Panel`

Output:

- `.agents/runs/panel-content-ui-polish/01-prd.md`

## Agent B: Architecture

Goal:

Keep this as a view-only polish pass.

Inputs:

- `.agents/runs/panel-content-ui-polish/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/panel-content-ui-polish/02-ard.md`
- `.agents/runs/panel-content-ui-polish/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Refine the panel hierarchy without changing provider behavior.

Necessity gate:

- Confirm `00-intake.md` has a `build` decision.
- Confirm no clarifying questions are open.

Write scope:

- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillActionViews.swift`
- `Sources/Spill/Panel/SpillFooterView.swift`
- `Sources/Spill/Panel/SpillPanelMetrics.swift`

Do not edit:

- private API usage
- refresh loops
- AX scanning internals
- unrelated preferences sections

Acceptance:

- Header, status rows, AI, actions, and footer are easier to scan.
- Settings and Quit remain visible.
- Panel smoke verification passes.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Validate that the panel remains compact and buildable.

Review scope:

- SwiftUI panel layout
- panel smoke logs
- run docs

Checks:

- PRD alignment
- ARD alignment
- `swift test`
- `panel-layout-smoke`
- workflow verification
- no committed secrets

Final report:

- findings first
- verification result
- residual risks
