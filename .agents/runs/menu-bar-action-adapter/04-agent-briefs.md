# Agent Briefs: Menu Bar Action Adapter

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside the assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer if action execution semantics, provider scope, or permission impact becomes unclear.
- Do not add system, AI, or window-management providers in this run.

## Agent A: Product

Goal:

Document the adapter as a narrow bridge from scanner snapshots to `SpillAction`.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/menu-bar-action-adapter/00-intake.md`
- `.agents/runs/stitch-panel-shell/06-closeout.md`

Output:

- `.agents/runs/menu-bar-action-adapter/01-prd.md`

## Agent B: Architecture

Goal:

Define the pure adapter and panel integration without introducing a provider registry.

Inputs:

- `.agents/runs/menu-bar-action-adapter/01-prd.md`
- `Sources/Spill/Providers/SpillActionModels.swift`
- `Sources/Spill/MenuBar/MenuBarItemSnapshot.swift`
- `Sources/Spill/Panel/SpillBarView.swift`

Output:

- `.agents/runs/menu-bar-action-adapter/02-ard.md`
- `.agents/runs/menu-bar-action-adapter/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Implement `MenuBarActionAdapter`, action state helpers, and panel rendering from `SpillAction`.

Necessity gate:

- Confirm `.agents/runs/menu-bar-action-adapter/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/Providers/SpillActionModels.swift`
- `Sources/Spill/Providers/MenuBarActionAdapter.swift`
- `Sources/Spill/Panel/SpillBarView.swift`

Do not edit:

- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Accessibility/`
- `Sources/Spill/Preferences/`

Acceptance:

- Snapshots map to actions.
- Action tile rendering uses action metadata.
- Existing scanner click behavior remains.
- No fake provider data is introduced.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Add focused adapter tests and run the verification pipeline.

Review scope:

- `Sources/Spill/Providers/`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Tests/SpillTests/MenuBarActionAdapterTests.swift`

Checks:

- PRD alignment
- ARD alignment
- unit tests
- build
- workflow gates
- runtime smoke

Final report:

- findings first
- verification result
- residual risks
