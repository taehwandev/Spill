# Agent Briefs: System CPU Provider

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer before PRD authoring if the goal, scope, value, UI behavior, feasibility, permission impact, or distribution impact is unclear.
- Do not let Agent A write the PRD while `00-intake.md` is still `needs-clarification`.

## Agent A: Product

Goal: Confirm CPU provider foundation is useful without deciding visible panel placement.

PRD authoring gate:

- Confirm `.agents/runs/system-cpu-provider/00-intake.md` has `Decision: build`.
- Confirm all clarifying questions are answered or explicitly marked as resolved.
- If not, ask the maintainer and stop without writing the PRD.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/system-cpu-provider/00-intake.md`

Output:

- `.agents/runs/system-cpu-provider/01-prd.md`

## Agent B: Architecture

Goal: Define CPU tick sampling and status mapping without panel integration.

Inputs:

- `.agents/runs/system-cpu-provider/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/system-cpu-provider/02-ard.md`
- `.agents/runs/system-cpu-provider/03-task-breakdown.yml`

## Agent C1: Builder

Goal: Implement `SystemCPUProvider` and tests.

Necessity gate:

- Confirm `.agents/runs/system-cpu-provider/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Tests/SpillTests/SystemCPUProviderTests.swift`

Do not edit:

- Panel SwiftUI views.
- Provider store.
- Menu bar trigger architecture.

Acceptance:

- `swift build` passes.
- `swift test` passes.
- CPU is not rendered in the panel yet.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal: Verify CPU mapping behavior and confirm no visible UI scope was added.

Review scope:

- CPU provider.
- CPU tests.
- Roadmap and closeout notes.

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
