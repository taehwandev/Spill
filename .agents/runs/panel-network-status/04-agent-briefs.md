# Agent Briefs: Panel Network Status

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- The request is clear and the run intake is accepted.

## Agent A: Product

Goal: Confirm Network belongs in the panel status section and captures receive/upload activity, not only route availability.

PRD authoring gate:

- Confirm `.agents/runs/panel-network-status/00-intake.md` has `Decision: build`.
- Confirm all clarifying questions are answered or explicitly marked as resolved.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/panel-network-status/00-intake.md`

Output:

- `.agents/runs/panel-network-status/01-prd.md`

## Agent B: Architecture

Goal: Wire Network through the existing status module architecture without adding a separate panel path, and compute throughput from sequential local interface counter samples.

Inputs:

- `.agents/runs/panel-network-status/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/panel-network-status/02-ard.md`
- `.agents/runs/panel-network-status/03-task-breakdown.yml`

## Agent C1: Builder

Goal: Add Network to the default panel status module set, report receive/upload throughput, and update tests.

Necessity gate:

- Confirm `.agents/runs/panel-network-status/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/Providers/SpillStatusModule.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`
- `Tests/SpillTests/PanelStoreTests.swift`

Do not edit:

- `Sources/Spill/MenuBar/SpillMenuBarStatusItem.swift`

Acceptance:

- Network appears in default panel status modules.
- Network shows receive/upload rates from local byte-counter deltas.
- Network remains configurable by existing status module settings.
- Focused tests pass.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal: Verify the panel Network row aligns with PRD and ARD, and that settings behavior and throughput sampling remain consistent.

Review scope:

- Module defaults and settings normalization.
- Panel store visible module state.
- Test expectations.

Checks:

- PRD alignment.
- ARD alignment.
- Focused tests.
- Full test suite.
- App build.
- Workflow verification.

Final report:

- findings first
- verification result
- residual risks
