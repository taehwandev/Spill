# Agent Briefs: System Power Provider

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer if the goal, scope, value, permission impact, or distribution impact is unclear.

## Agent A: Product

Goal: Confirm that power state is necessary, compact, and distribution-safe for the current product direction.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/system-power-provider/00-intake.md`

Output:

- `.agents/runs/system-power-provider/01-prd.md`

## Agent B: Architecture

Goal: Define a public-API provider architecture that can be tested without depending on live battery hardware.

Inputs:

- `.agents/runs/system-power-provider/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/system-power-provider/02-ard.md`
- `.agents/runs/system-power-provider/03-task-breakdown.yml`

## Agent C1: Builder

Goal: Implement `SystemPowerProvider`, tests, and compact panel footer integration.

Necessity gate:

- Confirm `.agents/runs/system-power-provider/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/Providers/SystemPowerProvider.swift`
- `Tests/SpillTests/SystemPowerProviderTests.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `.agents/design/stitch.md`

Do not edit:

- Private API or spacer behavior in menu bar controllers.
- Notch detection logic.
- Preferences unrelated to provider display.

Acceptance:

- `swift build` passes.
- `swift test` passes.
- The panel footer shows power as icon plus short value.
- No new permissions are introduced.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal: Verify provider mapping, public API boundaries, compact UI behavior, and workflow gates.

Review scope:

- Provider implementation.
- Unit tests.
- Panel footer integration.
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
