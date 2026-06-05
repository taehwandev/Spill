# Agent Briefs: AI Token Metering Local App Bridge

## Coordinator Notes

- Keep the local app bridge token-only and local-first.
- Do not collect prompts, commands, file paths, terminal output, diffs, logs,
  source content, environment values, or secrets.
- Do not add production cloud sync, Supabase writes, auth, recurring
  infrastructure, or background upload in this slice.
- Keep the app buildable and do not revert unrelated user changes.

## Agent A: Product

Goal:

Define the local-app side of AI token metering so the web dashboard can read
real local token-count data before cloud sync exists.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/ai-token-metering-local-app/00-intake.md`

Output:

- `.agents/runs/ai-token-metering-local-app/01-prd.md`

Acceptance:

- PRD states that unauthenticated users remain local-only.
- PRD states that only numeric counts, timestamps, model ids, latency, and enum
  labels are eligible.
- PRD explicitly excludes prompt and command content.

## Agent B: Architecture

Goal:

Define the local bridge, storage, sanitizer, and web integration boundary.

Inputs:

- `.agents/runs/ai-token-metering-local-app/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/ai-token-metering-local-app/02-ard.md`
- `.agents/runs/ai-token-metering-local-app/03-task-breakdown.yml`

Acceptance:

- Bridge binds to loopback only.
- Sanitizer uses allowlisted fields and rejects unknown fields.
- Web app treats the native bridge as the first local source and browser
  storage as fallback only.

## Agent C1: Builder

Goal:

Implement the local token usage bridge and wire the web dashboard to it without
changing the cloud-sync contract.

Write scope:

- `Sources/Spill/TokenMetering/`
- `Sources/Spill/App/AppDelegate.swift`
- `Tests/SpillTests/TokenUsageStoreTests.swift`
- `web/src/features/tokenMeteringDashboard/`
- `web/src/App.tsx`
- `web/test/`

Do not edit:

- Release signing, notarization, Sparkle keys, GitHub release settings, or
  production deployment configuration.
- Any code that would upload usage data to a server.

Acceptance:

- App startup starts the bridge unless explicitly disabled by environment.
- Bridge exposes health, read, append, and clear endpoints on `127.0.0.1:48731`.
- Unsafe content-like fields are rejected at the Swift boundary and sanitized in
  the web client.
- React dashboard code is feature-local and not concentrated in one oversized
  route file.

Final report:

- Changed files.
- Behavior implemented.
- Commands run.
- Any blockers or residual risks.

## Agent C2: Verifier

Goal:

Verify token-only behavior, local-only bridge binding, React structure, and
basic app/web runtime behavior.

Checks:

- `swift test`
- `./scripts/build-app.sh`
- `npm test` from `web/`
- `npm run build` from `web/`
- `git diff --check`
- VibeGuard audit
- `curl -sS http://127.0.0.1:48731/v1/usage/health`
- `curl -sS http://127.0.0.1:48731/v1/usage/events`

Final report:

- Findings first if any.
- Verification result.
- Residual risks.
