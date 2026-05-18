# Agent Briefs: Panel Glass Footer Contrast

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Confirm `00-intake.md` has `Decision: build`.
- This task is scoped to transparent dashboard footer contrast plus the same weak active-blue issue in the clock-adjacent status item.

## Agent A: Product

Goal:

Document the maintainer's request to preserve a transparent footer while improving foreground readability.

PRD authoring gate:

- Confirm `00-intake.md` has `Decision: build`.
- Confirm there are no blocking clarifying questions.

Inputs:

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/design/stitch.md`
- `.agents/runs/panel-glass-footer-contrast/00-intake.md`

Output:

- `.agents/runs/panel-glass-footer-contrast/01-prd.md`

## Agent B: Architecture

Goal:

Keep the solution limited to SwiftUI footer foreground roles.

Inputs:

- `.agents/runs/panel-glass-footer-contrast/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/panel-glass-footer-contrast/02-ard.md`
- `.agents/runs/panel-glass-footer-contrast/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Make footer values readable over light and dark glass without restoring a visible footer background.

Write scope:

- `Sources/Spill/Panel/SpillFooterContrastStyle.swift`
- `Sources/Spill/Panel/SpillFooterView.swift`
- `Sources/Spill/Panel/SpillStatusStyle.swift`
- `Sources/Spill/Panel/SpillPanelState.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Tests/SpillTests/SpillFooterContrastStyleTests.swift`

Do not edit:

- `Sources/Spill/Providers`
- `Sources/Spill/Settings`

Acceptance:

- Values use primary foreground role.
- Status colors are applied to icons.
- Active/refreshing accents use teal instead of blue.
- Unit, build, and panel smoke checks pass.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Verify the footer contrast behavior and regression gates.

Review scope:

- Footer contrast style model
- Footer rendering
- Focused tests

Checks:

- PRD alignment
- ARD alignment
- `swift test`
- `swift build`
- panel layout smoke

Final report:

- findings first
- verification result
- residual risks
