# Agent Briefs: Startup Permission Timeout

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer before PRD authoring if startup behavior, permission
  impact, or acceptance criteria become unclear.

## Agent A: Product

Goal:

Define launch reliability expectations for permission-dependent window actions.

PRD authoring gate:

- Confirm `.agents/runs/startup-permission-timeout/00-intake.md` has
  `Decision: build`.
- Confirm there are no unresolved clarifying questions.

Inputs:

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/runs/startup-permission-timeout/00-intake.md`

Output:

- `.agents/runs/startup-permission-timeout/01-prd.md`

## Agent B: Architecture

Goal:

Define where startup, permission checks, focused-window lookup, and smoke
diagnostics belong.

Inputs:

- `.agents/runs/startup-permission-timeout/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/startup-permission-timeout/02-ard.md`
- `.agents/runs/startup-permission-timeout/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Remove launch-time focused-window lookup and add regression tests.

Necessity gate:

- Confirm `.agents/runs/startup-permission-timeout/00-intake.md` has a `build`
  decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `Sources/Spill/Providers/WindowActionProvider.swift`
- `Tests/SpillTests/WindowActionStoreTests.swift`
- `Sources/Spill/App/AppDelegate.swift`
- `scripts/verify-panel-layout-smoke.sh`

Do not edit:

- Menu bar trigger behavior.
- Preferences UI.
- Distribution scripts.

Acceptance:

- Store initialization does not read the focused window.
- Untrusted refresh and perform paths skip the focused-window controller.
- Trusted refresh remains functional.
- Smoke diagnostics pass reliably.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Verify startup reliability, permission fallback, and panel smoke behavior.

Review scope:

- `WindowActionStore`
- `FocusedWindowController` protocol boundary
- App smoke diagnostics

Checks:

- PRD alignment
- ARD alignment
- build
- unit tests
- runtime smoke
- panel open smoke
- panel layout smoke
- permission-required behavior

Final report:

- findings first
- verification result
- residual risks
