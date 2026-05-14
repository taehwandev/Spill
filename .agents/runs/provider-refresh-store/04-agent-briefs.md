# Agent Briefs: Provider Refresh Store

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer if the goal, scope, value, permission impact, or distribution impact is unclear.

## Agent A: Product

Goal: Confirm that caching provider values is necessary before adding more provider types.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/provider-refresh-store/00-intake.md`

Output:

- `.agents/runs/provider-refresh-store/01-prd.md`

## Agent B: Architecture

Goal: Define the smallest store architecture that removes direct provider reads from `SpillBarView`.

Inputs:

- `.agents/runs/provider-refresh-store/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/provider-refresh-store/02-ard.md`
- `.agents/runs/provider-refresh-store/03-task-breakdown.yml`

## Agent C1: Builder

Goal: Implement `SystemStatusStore`, test it, and wire the panel to cached provider state.

Necessity gate:

- Confirm `.agents/runs/provider-refresh-store/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Tests/SpillTests/SystemStatusStoreTests.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`

Do not edit:

- Menu bar trigger architecture.
- Notch detection.
- Preferences.

Acceptance:

- Store tests pass.
- `SpillBarView` observes store state instead of reading providers directly.
- Existing panel behavior is preserved.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal: Verify store behavior, no direct provider reads in the view, and workflow gates.

Review scope:

- Store implementation.
- Panel wiring.
- Tests.
- Run documentation.

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
