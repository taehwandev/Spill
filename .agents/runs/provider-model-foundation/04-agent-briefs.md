# Agent Briefs: Provider Model Foundation

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable at every handoff.
- This feature is source foundation only; no user-visible UI behavior should change.
- Do not edit global docs or `.agents/specs/` for this feature.
- Report changed files, commands run, behavior verified, and assumptions.

## Agent A: Product

Goal:

Clarify why provider model foundation is needed and keep the product scope limited to no visible behavior change.

Inputs:

- `.agents/runs/provider-model-foundation/00-intake.md`
- `.agents/runs/example-control-tray/01-prd.md`
- `.agents/runs/example-control-tray/02-ard.md`

Output:

- `.agents/runs/provider-model-foundation/01-prd.md`

Acceptance:

- PRD explicitly says no UI behavior change.
- PRD names `SpillStatusItem`, `SpillAction`, and provider protocols.
- PRD includes functional requirements and acceptance criteria for source-level foundation work.

## Agent B: Architecture

Goal:

Define the smallest architecture that supports future providers without coupling models to UI or current scanner internals.

Inputs:

- `.agents/runs/provider-model-foundation/01-prd.md`
- `Sources/Spill/MenuBar/MenuBarItemSnapshot.swift`
- `Sources/Spill/MenuBar/AXMenuBarItemScanner.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`

Output:

- `.agents/runs/provider-model-foundation/02-ard.md`
- `.agents/runs/provider-model-foundation/03-task-breakdown.yml`

Acceptance:

- ARD separates action description from action execution.
- ARD prefers snapshot-style provider reads.
- ARD includes permission and failure mode handling.
- Task breakdown has narrow write scopes and forbids UI edits for foundation tasks.

## Agent C1: Model Builder

Goal:

Implement plain model types for status items and actions.

Write scope:

- `Sources/Spill/Providers/SpillProviderModels.swift`

Read scope:

- `.agents/runs/provider-model-foundation/01-prd.md`
- `.agents/runs/provider-model-foundation/02-ard.md`
- `Sources/Spill/MenuBar/MenuBarItemSnapshot.swift`

Do not edit:

- `Sources/Spill/Panel/`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/App/`
- `.agents/specs/`

Acceptance:

- `SpillStatusItem` and `SpillAction` are plain value models.
- Models have stable identity and deterministic ordering metadata.
- Models avoid AppKit view objects and execution closures.
- `swift build` passes.

Final report:

- changed files
- model fields added
- commands run
- assumptions and blockers

## Agent C2: Protocol Builder

Goal:

Implement provider protocols that can supply status/action snapshots and execute actions by ID.

Write scope:

- `Sources/Spill/Providers/SpillProviderProtocols.swift`

Read scope:

- `.agents/runs/provider-model-foundation/02-ard.md`
- `Sources/Spill/MenuBar/MenuBarScanCoordinator.swift`
- `Sources/Spill/MenuBar/AXMenuBarItemScanner.swift`

Do not edit:

- `Sources/Spill/Panel/`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/App/`
- `.agents/specs/`

Acceptance:

- Protocols are UI-independent.
- Provider reads are snapshot-style.
- Action execution is represented separately from `SpillAction`.
- `swift build` passes.

Final report:

- changed files
- protocol signatures added
- commands run
- assumptions and blockers

## Agent C3: Verification Builder

Goal:

Add focused compile/model tests only if the package already supports an appropriate test target.

Write scope:

- `Tests/SpillTests/ProviderModelFoundationTests.swift`

Read scope:

- `Package.swift`
- new provider model/protocol files

Do not edit:

- Source UI files.
- Package structure unless explicitly required and approved by the coordinator.
- `.agents/specs/`

Acceptance:

- Tests cover identity/hashability and a simple provider fixture if feasible.
- If no test target exists, record that `swift build` is the automated check.

Final report:

- changed files
- commands run
- test coverage added or reason omitted

## Agent D: Verifier

Goal:

Confirm the foundation compiles and does not change existing behavior.

Review scope:

- Files changed by builder agents.
- `.agents/runs/provider-model-foundation/01-prd.md`
- `.agents/runs/provider-model-foundation/02-ard.md`

Checks:

- PRD alignment.
- ARD alignment.
- Build passes.
- No UI file changes unless explicitly justified.
- No new permissions, polling, network calls, or visible panel content.
- Existing status item and panel behavior still work.

Final report:

- findings first
- verification result
- commands run
- residual risks
