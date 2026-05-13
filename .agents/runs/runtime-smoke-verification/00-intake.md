# Feature Intake

## Feature ID

`runtime-smoke-verification`

## Request

Add an automated runtime smoke test that verifies Spill can build as an app bundle, launch, reach startup readiness, and exit cleanly. Existing verification checks build output and static architecture rules, but does not prove that the bundled macOS app actually starts.

## User Problem

Maintainers need a repeatable verification step before manual visual testing. Without a runtime smoke test, changes to app lifecycle, status item setup, packaging, or startup permission behavior can pass static checks while failing at launch time.

## Necessity Assessment

- Necessary for current product direction: yes. Spill is a native macOS utility and needs launch-level verification.
- Better solved by Spill, macOS, or an existing dedicated app: Spill should own this repository-level smoke test.
- Small enough for the compact tray: yes. This is test infrastructure and does not affect normal UI.
- Private API, fragile behavior, or distribution risk: no. The smoke mode uses environment variables and public app lifecycle APIs.
- Cost of not building it: startup regressions remain manual-only and easy to miss.

Decision: `build`

Reason: Runtime smoke verification is required before relying on future UI and provider work.

## Clarifying Questions

Questions:

- None. The need is clear, and the scope is limited to non-interactive startup verification.

## Target User

Maintainers, verifier agents, and contributors working on app lifecycle or UI entry points.

## Proposed Product Shape

No normal user-facing behavior change. When `SPILL_SMOKE_TEST=1` is set, the app suppresses startup Preferences and Accessibility prompts, prints readiness markers, then exits automatically.

## Constraints

- macOS/public API constraints: the smoke test must run as a local macOS app process.
- permission constraints: the smoke mode must not request Accessibility permission.
- distribution constraints: the script should use the same local `.app` bundle path as development builds.
- performance constraints: the smoke run should complete quickly.

## Non-goals

- Do not visually inspect menu bar pixels.
- Do not automate Accessibility permission approval.
- Do not replace manual notched-display testing.
- Do not change normal startup behavior.

## Open Questions

- None.

## Decision

Status: `accepted`

Reason: This adds a missing verification layer with low implementation risk.
