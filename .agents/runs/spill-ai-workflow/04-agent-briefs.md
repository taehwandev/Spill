# Agent Briefs: Spill AI Workflow

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- The goal, scope, value, UI behavior, feasibility, permission impact, and
  distribution impact are resolved in `00-intake.md`.
- Do not write implementation outside the accepted local-only AI workflow scope.

## Agent A: Product

Goal: Keep the AI strip compact while making each detected local AI tool
actionable.

PRD authoring gate:

- Confirm `.agents/runs/spill-ai-workflow/00-intake.md` has `Decision: build`.
- Confirm all clarifying questions are answered or explicitly marked as resolved.
- If not, ask the maintainer and stop without writing the PRD.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/spill-ai-workflow/00-intake.md`

Output:

- `.agents/runs/spill-ai-workflow/01-prd.md`

## Agent B: Architecture

Goal: Keep local tool detection, recommendation mapping, and pasteboard UI
actions in separate boundaries.

Inputs:

- `.agents/runs/spill-ai-workflow/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/spill-ai-workflow/02-ard.md`
- `.agents/runs/spill-ai-workflow/03-task-breakdown.yml`

## Agent C1: Builder

Goal: Implement the local AI next-action recommendation and copy-command MVP.

Necessity gate:

- Confirm `.agents/runs/spill-ai-workflow/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/Providers/LocalAIStatusProvider.swift`
- `Sources/Spill/Panel/SpillStatusDetailModels.swift`
- `Sources/Spill/Panel/SpillStatusDetailPopover.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- focused tests for those files

Do not edit:

- AgentCat integration files or commands
- release, signing, update, or dependency files
- existing app icon script changes unless separately requested

Acceptance:

- AI detail shows a `Next` recommendation.
- Safe static commands can be copied for supported local tools.
- OpenAI config remains secret-safe.
- No new network calls, telemetry uploads, permissions, or shell execution.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal: Verify product fit, privacy, compact UI, and focused tests.

Review scope:

- PRD/ARD alignment
- local AI recommendation mapping
- detail popover UI action
- secret and prompt exposure risk

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
