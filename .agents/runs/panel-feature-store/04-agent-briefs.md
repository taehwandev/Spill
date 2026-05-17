# Agent Briefs: Panel Feature Store

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- This is a behavior-preserving architecture slice. Do not redesign the panel.

## Agent A: Product

Goal:

Document the behavior-preserving first slice for panel feature-store migration.

PRD authoring gate:

- Confirm `.agents/runs/panel-feature-store/00-intake.md` has
  `Decision: build`.
- Confirm all clarifying questions are resolved.

Inputs:

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/runs/panel-feature-store/00-intake.md`

Output:

- `.agents/runs/panel-feature-store/01-prd.md`

## Agent B: Architecture

Goal:

Define the narrow store/state/action boundary and migration constraints.

Inputs:

- `.agents/runs/panel-feature-store/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/panel-feature-store/02-ard.md`
- `.agents/runs/panel-feature-store/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Introduce `PanelState`, `PanelAction`, and `PanelStore`, then wire
`SpillBarView` to render from the derived state.

Necessity gate:

- Confirm `.agents/runs/panel-feature-store/00-intake.md` has a `build`
  decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/Panel/PanelStore.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Tests/SpillTests/PanelStoreTests.swift`

Do not edit:

- Release workflows.
- Website files.
- Packaging scripts.
- Unrelated providers.

Acceptance:

- Panel display derivation is owned by `PanelStore`.
- Tests cover the derived state.
- Existing panel behavior and smoke checks pass.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Verify that the store migration is behavior-preserving.

Review scope:

- `Sources/Spill/Panel`
- `Tests/SpillTests/PanelStoreTests.swift`
- `.agents/runs/panel-feature-store`

Checks:

- PRD alignment
- ARD alignment
- tests
- build
- runtime smoke
- panel open smoke
- panel layout smoke

Final report:

- findings first
- verification result
- residual risks
