# Agent Briefs: AI Token Metering Web Dashboard

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- The token metering product must never collect commands, prompts, responses,
  file paths, repo names, branch names, commit messages, terminal output, error
  log bodies, diffs, source content, environment values, or secrets.
- For this first slice, do not add production backend credentials, analytics
  SDKs, paid services, recurring infrastructure, or Mac app sync upload code.

## Agent A: Product

Goal:

Write and maintain the product contract for local-first AI token metering and
the web dashboard.

PRD authoring gate:

- Confirm `.agents/runs/ai-token-metering-web/00-intake.md` has
  `Decision: build`.
- Confirm all clarifying questions are answered or explicitly marked as
  resolved.
- If not, ask the maintainer and stop without writing the PRD.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/ai-token-metering-web/00-intake.md`

Output:

- `.agents/runs/ai-token-metering-web/01-prd.md`

Acceptance:

- PRD states local-only behavior before login.
- PRD states login plus opt-in cloud sync behavior.
- PRD states separate detailed cloud breakdown opt-in behavior.
- PRD lists the allowed token-only payload fields and forbidden content fields.

## Agent B: Architecture

Goal:

Translate the PRD into the smallest safe implementation slice and future auth/db
direction.

Inputs:

- `.agents/runs/ai-token-metering-web/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/ai-token-metering-web/02-ard.md`
- `.agents/runs/ai-token-metering-web/03-task-breakdown.yml`

Acceptance:

- ARD scopes current code work to `web/**`.
- ARD defers Supabase/Vercel production backend work to a later slice.
- ARD defines an allowlisted sync-safe event model.
- ARD identifies no Swift source changes for this slice.

## Agent C1: Builder

Goal:

Implement the cloud React dashboard preview under `web/` only.

Necessity gate:

- Confirm `.agents/runs/ai-token-metering-web/00-intake.md` has a `build`
  decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `web/**`

Do not edit:

- `Sources/Spill/**`
- `docs/**`
- `.agents/runs/ai-token-metering-web/**`
- `Package.swift`
- `Package.resolved`
- signing, notarization, release, or update files

Acceptance:

- Create a React dashboard runnable locally without production credentials.
- Use a dense operational dashboard layout, not a landing page.
- Include sync mode status, token KPIs, task-type breakdown, token-source
  hotspots, session trace, and privacy/sync settings.
- Keep data behind fixtures and a clearly named local/demo boundary.
- Define a sync-safe usage event type and allowlist sanitizer that cannot emit
  forbidden fields.
- Do not add Supabase credentials, service-role keys, analytics SDKs, or backend
  deployment config in this slice.
- Preserve user-owned changes and do not revert unrelated edits.

Verification:

- Run the closest available web check, preferably `npm run build` from `web/`.
- If dependencies cannot be installed due sandbox/network restrictions, report
  the command and blocker exactly.
- Inspect the dashboard manually if a dev server can run.

Final report:

- changed files
- behavior implemented
- commands run
- blockers or residual risks

## Agent C2: Verifier

Goal:

Review the final web patch against the PRD, ARD, repo-local rules, and privacy
contract.

Review scope:

- `.agents/runs/ai-token-metering-web/**`
- `web/**`

Checks:

- PRD alignment
- ARD alignment
- build/typecheck result
- manual dashboard behavior
- forbidden field absence
- no secrets or production credential files
- no unrelated Swift/docs/release changes

Final report:

- findings first
- verification result
- residual risks
