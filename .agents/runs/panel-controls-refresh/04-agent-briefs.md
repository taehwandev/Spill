# Agent Briefs: Panel Controls Refresh

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- The maintainer explicitly asked to update documentation before continuing implementation.
- The ambiguity gate is resolved in `00-intake.md`.
- Keep the panel compact; do not turn graphs into a dashboard.

## Agent A: Product

Goal:

- Convert maintainer feedback into a concrete PRD covering live menu bar metrics, GPU removal, storage replacement, panel sparklines, Sleep Guard duration configuration, panel Quit, and Settings icon removal.

PRD authoring gate:

- Confirm `.agents/runs/panel-controls-refresh/00-intake.md` has `Decision: build`.
- Confirm all clarifying questions are answered or explicitly marked as resolved.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/panel-controls-refresh/00-intake.md`

Output:

- `.agents/runs/panel-controls-refresh/01-prd.md`

## Agent B: Architecture

Goal:

- Define provider, settings, refresh, and panel boundaries for the requested changes.

Inputs:

- `.agents/runs/panel-controls-refresh/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/panel-controls-refresh/02-ard.md`
- `.agents/runs/panel-controls-refresh/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

- Implement the requested behavior while preserving compact panel constraints and public API boundaries.

Necessity gate:

- Confirm `.agents/runs/panel-controls-refresh/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillFooterView.swift`
- `Sources/Spill/Panel/SpillPanelMetrics.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Providers/SystemStorageProvider.swift`
- `Sources/Spill/Providers/SpillStatusModule.swift`
- `Sources/Spill/Preferences/DetectedItemsListView.swift`
- `Sources/Spill/Preferences/PowerPreferencesSection.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Tests/SpillTests`

Do not edit:

- Entitlements.
- Private API gates.
- Unrelated preference sections.
- Unrelated run folders.

Acceptance:

- Menu bar CPU and memory values keep refreshing after panel close.
- GPU is removed from primary panel status.
- Storage appears as a primary panel row.
- CPU, Memory, and Storage rows include compact sparklines.
- Sleep Guard default duration is configurable and persisted.
- Panel footer includes Quit.
- Settings icon removal works immediately and persists.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

- Verify behavior, compactness, persistence, and workflow gates.

Review scope:

- Refresh loop separation.
- Storage provider accuracy and unavailable states.
- Panel graph rendering and compact layout.
- Sleep Guard duration settings.
- Panel Quit behavior.
- Settings icon removal.

Checks:

- PRD alignment.
- ARD alignment.
- `swift test`.
- `python3 .agents/scripts/workflow.py panel-layout-smoke`.
- `python3 .agents/scripts/workflow.py verify`.
- Manual behavior for menu bar metric updates and Settings removal.

Final report:

- findings first
- verification result
- residual risks
