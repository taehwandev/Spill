# Agent Briefs: Stitch-Inspired Panel Shell

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside the assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer if product intent, UI scope, permission impact, or distribution impact becomes unclear.
- Do not introduce fake system, AI, or provider values.

## Agent A: Product

Goal:

Translate the Stitch `Spill Multi-Widget Panel` screen into a compact native panel requirement that works with current Spill state only.

Inputs:

- `.agents/specs/prd.md`
- `.agents/design/stitch.md`
- `.agents/runs/stitch-panel-shell/00-intake.md`

Output:

- `.agents/runs/stitch-panel-shell/01-prd.md`

## Agent B: Architecture

Goal:

Define how the Stitch-inspired shell maps to the existing NSPanel and SwiftUI implementation without new provider data sources.

Inputs:

- `.agents/runs/stitch-panel-shell/01-prd.md`
- `.agents/specs/ard.md`
- `Sources/Spill/Panel/`

Output:

- `.agents/runs/stitch-panel-shell/02-ard.md`
- `.agents/runs/stitch-panel-shell/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Implement the compact panel shell with header, status, actions, and footer sections.

Necessity gate:

- Confirm `.agents/runs/stitch-panel-shell/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Panel/SpillPanelLayout.swift`
- `Sources/Spill/Panel/SpillPanelMetrics.swift`

Do not edit:

- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Providers/`
- `Sources/Spill/Preferences/`

Acceptance:

- Header, status, action, and footer sections render from current app state.
- Existing action press behavior remains wired through `AXMenuBarItemScanner`.
- No fake CPU, memory, battery, AI, or provider data appears.
- `swift build` and `swift test` pass.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Review the panel shell against the PRD and ARD, then run automated gates.

Review scope:

- `.agents/runs/stitch-panel-shell/`
- `.agents/design/stitch.md`
- `Sources/Spill/Panel/`

Checks:

- PRD alignment
- ARD alignment
- build
- tests
- workflow gates
- runtime smoke
- permission, scanning, empty, and ready state source inspection
- absence of fake provider data

Final report:

- findings first
- verification result
- residual risks
