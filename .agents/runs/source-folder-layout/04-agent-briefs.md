# Agent Briefs: Source Folder Layout

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer if the goal, scope, value, permission impact, or distribution impact is unclear.

## Agent A: Product

Goal:

Confirm this is a non-behavioral source organization slice.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/source-folder-layout/00-intake.md`

Output:

- `.agents/runs/source-folder-layout/01-prd.md`

## Agent B: Architecture

Goal:

Define source folders that match the existing architecture boundaries.

Inputs:

- `.agents/runs/source-folder-layout/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/source-folder-layout/02-ard.md`
- `.agents/runs/source-folder-layout/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Move Swift files into responsibility-based folders.

Necessity gate:

- Confirm `.agents/runs/source-folder-layout/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/App/`
- `Sources/Spill/Accessibility/`
- `Sources/Spill/MenuBar/`
- `Sources/Spill/Panel/`
- `Sources/Spill/Preferences/`
- `Sources/Spill/Settings/`
- `.agents/specs/ard.md`

Do not edit:

- `Package.swift`
- Swift type bodies unless a build issue requires it

Acceptance:

- Swift files are grouped by responsibility.
- `swift build` passes.
- Workflow docs, readiness, and language gates pass.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Review the move-only patch for missing files and accidental behavior changes.

Review scope:

- `Sources/Spill/`
- `.agents/specs/ard.md`
- `.agents/runs/source-folder-layout/`

Checks:

- PRD alignment
- ARD alignment
- build
- folder layout
- no implementation refactor

Final report:

- findings first
- verification result
- residual risks
