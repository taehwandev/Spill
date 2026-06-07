# Agent Briefs: Token Dashboard Process Surface

## Coordinator Notes

- Confirm `00-intake.md` has `Decision: build` before editing.
- Keep the compact Spill panel small; do not embed the detailed dashboard inside
  it.
- Preserve the token-only privacy boundary. Do not add prompt, command, file,
  log, diff, source, environment, transcript, or secret collection.
- Do not let the helper process duplicate main-app side effects such as status
  item creation, menu bar scanning, hotkeys, adapter setup, bridge server, or
  token ingestion.
- Keep packaging and runtime-smoke verification in scope when changing the
  helper bundle.

## Agent A: Product

Goal:

Define the separate dashboard surface and close/quit semantics.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/token-dashboard-process/00-intake.md`

Output:

- `.agents/runs/token-dashboard-process/01-prd.md`

Acceptance:

- AI glance entry, dashboard surface, close behavior, non-goals, and privacy
  constraints are explicit.

## Agent B: Architecture

Goal:

Define the bundled helper app architecture and the main/helper responsibility
split.

Inputs:

- `.agents/runs/token-dashboard-process/01-prd.md`
- `.agents/specs/ard.md`
- `Sources/Spill/TokenMetering`
- `scripts/build-app.sh`

Output:

- `.agents/runs/token-dashboard-process/02-ard.md`
- `.agents/runs/token-dashboard-process/03-task-breakdown.yml`

Acceptance:

- Helper launch, fallback, settings handoff, local-store read behavior, and
  packaging risks are documented.

## Agent C1: Builder

Goal:

Implement the dashboard helper process and route dashboard entry points to it.

Write scope:

- `Sources/Spill/App/SpillMain.swift`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardProcess.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardLauncher.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardAppDelegate.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardWindowController.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `scripts/build-app.sh`

Do not edit:

- Token usage event schema.
- Token sanitizer privacy boundary.
- Cloud sync or upload policy.

Acceptance:

- Helper process launches from the main app.
- Helper owns only dashboard state and dashboard window lifecycle.
- Main app remains running after the helper closes or quits.
- In-process fallback remains available when the helper bundle is unavailable.

## Agent C2: Verifier

Goal:

Verify behavior, packaging, and privacy boundaries.

Review scope:

- Dashboard helper process files.
- Build script helper bundle output.
- Runtime smoke script.
- Token dashboard tests.

Checks:

- `swift test`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `codesign --verify --deep --strict --verbose=2 .build/Spill.app`
- Manual helper close/quit behavior when a GUI session is available.

Final report:

- Findings first.
- Verification result.
- Residual risks around helper packaging, signing, and main/helper handoff.
