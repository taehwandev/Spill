# Agent Briefs: <Feature Name>

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer before PRD authoring if the goal, scope, value, UI behavior, feasibility, permission impact, or distribution impact is unclear.
- Do not let Agent A write the PRD while `00-intake.md` is still `needs-clarification`.
- For settings work, require the accepted surface-impact map before implementation. AI settings must address Preferences, the compact panel/general dashboard, the separate AI dashboard helper, and the clock-adjacent AI menu-bar glance.
- Cross-process settings briefs must name persistence, notification or IPC transport, receiver reload/invalidation, update latency, and the nearest propagation tests.

## Agent A: Product

Goal:

PRD authoring gate:

- Confirm `.agents/runs/<feature>/00-intake.md` has `Decision: build`.
- Confirm all clarifying questions are answered or explicitly marked as resolved.
- If not, ask the maintainer and stop without writing the PRD.

Inputs:

- `.agents/specs/prd.md`
- `.agents/specs/prd/<owning-domain-prd>.md`
- `.agents/runs/<feature>/00-intake.md`

Output:

- `.agents/runs/<feature>/01-prd.md`

## Agent B: Architecture

Goal:

Inputs:

- `.agents/runs/<feature>/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/<feature>/02-ard.md`
- `.agents/runs/<feature>/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Necessity gate:

- Confirm `.agents/runs/<feature>/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- 

Do not edit:

- 

Acceptance:

- 

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Review scope:

- 

Checks:

- PRD alignment
- ARD alignment
- build
- manual behavior
- permission states
- settings persistence/default/migration
- cross-process propagation and receiver reload
- every affected dashboard, helper-app, panel, and menu-bar surface
- absence of undocumented polling, restart, reopen, manual refresh, or upload-sync dependencies

Final report:

- findings first
- verification result
- residual risks
