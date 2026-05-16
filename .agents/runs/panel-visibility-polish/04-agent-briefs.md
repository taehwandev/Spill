# Agent Briefs: Panel Visibility Polish

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- The ambiguity gate is resolved in `00-intake.md`.
- The maintainer's latest feedback is about visible trust, not new provider scope.
- No subagents were spawned for this run; the coordinator handled the coupled UI and provider display updates directly.

## Agent A: Product

Goal:

- Convert maintainer feedback into a compact PRD for menu bar status visibility, panel density, Settings/Quit discoverability, and decimal metric display.

PRD authoring gate:

- Confirm `.agents/runs/panel-visibility-polish/00-intake.md` has `Decision: build`.
- Confirm all clarifying questions are answered or explicitly marked as resolved.
- If not, ask the maintainer and stop without writing the PRD.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/panel-visibility-polish/00-intake.md`

Output:

- `.agents/runs/panel-visibility-polish/01-prd.md`

## Agent B: Architecture

Goal:

- Define the smallest architecture change that keeps provider data model ownership intact while improving the panel and menu bar presentation.

Inputs:

- `.agents/runs/panel-visibility-polish/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/panel-visibility-polish/02-ard.md`
- `.agents/runs/panel-visibility-polish/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

- Implement the panel and menu bar polish without changing permissions or introducing new data collectors.

Necessity gate:

- Confirm `.agents/runs/panel-visibility-polish/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/Panel/SpillActionViews.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Panel/SpillPanelMetrics.swift`
- `Sources/Spill/Panel/SpillStatusDetailModels.swift`
- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Sources/Spill/Providers/SystemMemoryProvider.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Tests/SpillTests/SpillPanelLayoutTests.swift`
- `Tests/SpillTests/SystemStatusStoreTests.swift`

Do not edit:

- Entitlement files.
- Permission prompts.
- Provider collection mechanisms beyond display semantics.

Acceptance:

- Menu bar chips show module SF Symbol icons instead of tiny dots.
- Menu bar percentage values default to one decimal place.
- Initial CPU sampling no longer appears as a gray placeholder or `--`.
- Disabled CPU remains explicitly unavailable.
- Panel status cards expose useful inline detail rows.
- Header includes visible Settings and Quit controls.
- Window and menu bar controls are easier to see and hit.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

- Verify the display behavior, test updates, and workflow gates for the panel visibility polish.

Review scope:

- Provider display strings and states.
- Panel layout constraints.
- Menu bar chip rendering.
- Settings/Quit action wiring.
- Regression tests and workflow verification.

Checks:

- PRD alignment
- ARD alignment
- build
- manual behavior
- permission states
- `swift test`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`
- `python3 .agents/scripts/workflow.py verify`

Final report:

- findings first
- verification result
- residual risks
