# Agent Briefs: CPU Core Chart Toggle

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert unrelated edits in panel window-action files.
- Keep the panel compact.
- Use public macOS APIs only.
- Report changed files and verification commands.

## Agent A: Product

Goal: Confirm CPU core chart mode is a compact optional status enhancement.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/cpu-core-chart-toggle/00-intake.md`

Output:

- `.agents/runs/cpu-core-chart-toggle/01-prd.md`

## Agent B: Architecture

Goal: Extend existing CPU/status architecture without adding a separate provider or dashboard layout.

Inputs:

- `.agents/specs/ard.md`
- `.agents/runs/cpu-core-chart-toggle/01-prd.md`

Output:

- `.agents/runs/cpu-core-chart-toggle/02-ard.md`
- `.agents/runs/cpu-core-chart-toggle/03-task-breakdown.yml`

## Agent C: Builder

Goal: Add per-core CPU data, persisted Preferences toggle, compact core-bar rendering, and zero-formatting fixes.

Write scope:

- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillStatusDetailModels.swift`
- `Sources/Spill/MenuBar/MenuBarStatusDisplayOptions.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/Preferences/StatusModulesPreferencesSection.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- focused tests

Acceptance:

- Toggle defaults off and persists.
- CPU core bars appear only when enabled and core history exists.
- Aggregate CPU display remains the default.
- Sampling and tiny non-zero usage avoid misleading `0%`.

## Agent D: Verifier

Goal: Verify behavior, compact layout, and workflow compliance.

Checks:

- Focused tests.
- Full Swift test suite.
- App build.
- Panel layout smoke.
- Workflow verification.

Final report:

- findings first if any
- verification result
- residual risks
