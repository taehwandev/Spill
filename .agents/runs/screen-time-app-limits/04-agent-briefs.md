# Agent Briefs: Screen Time App Limits Compatibility

## Coordinator Notes

- Do not attempt to bypass Screen Time.
- Use public APIs only.
- Keep guidance concise because Preferences are not a documentation page.
- Preserve the existing status-click smoke test.

## Agent A: Product

Goal:

Define the user-facing recovery path for Screen Time App Limits and Downtime.

Inputs:

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/runs/screen-time-app-limits/00-intake.md`

Output:

- `.agents/runs/screen-time-app-limits/01-prd.md`

## Agent B: Architecture

Goal:

Define a public-API settings opener and documentation-only mitigation strategy.

Inputs:

- `.agents/runs/screen-time-app-limits/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/screen-time-app-limits/02-ard.md`
- `.agents/runs/screen-time-app-limits/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Add Screen Time settings guidance without adding unsupported Screen Time control.

Write scope:

- `Sources/Spill/App/ScreenTimeSettings.swift`
- `Sources/Spill/Preferences/GeneralPreferencesSection.swift`
- `.agents/README.md`
- `.agents/scripts/workflow.py`
- `README.md`

Do not edit:

- Panel UI.
- Window actions.
- Accessibility scanner behavior.

Acceptance:

- Preferences can open Screen Time settings.
- README documents Always Allowed and independent launch.
- No bypass claims.

## Agent C2: Verifier

Goal:

Verify build, status-click smoke, docs, and workflow gates.

Checks:

- `swift test`
- `swift build`
- `./scripts/build-app.sh`
- `./scripts/verify-status-click-smoke.sh`
- `python3 .agents/scripts/workflow.py verify`
- `git diff --check`
