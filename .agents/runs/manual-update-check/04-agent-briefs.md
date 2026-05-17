# Agent Briefs: Manual Update Check

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- Existing `docs/index.html` and `.agents/runs/landing-page-showcase` changes are
  owned by another agent. Do not edit them.
- UI scope is Preferences and menus only; do not add panel content.

## Agent A: Product

Goal: Define the static-manifest manual update experience.

PRD authoring gate:

- Confirm `.agents/runs/manual-update-check/00-intake.md` has `Decision: build`.
- Confirm all clarifying questions are answered or explicitly marked as resolved.
- If not, ask the maintainer and stop without writing the PRD.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/manual-update-check/00-intake.md`

Output:

- `.agents/runs/manual-update-check/01-prd.md`

## Agent B: Architecture

Goal: Specify release manifest generation, app update checking, and UI wiring.

Inputs:

- `.agents/runs/manual-update-check/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/manual-update-check/02-ard.md`
- `.agents/runs/manual-update-check/03-task-breakdown.yml`

## Agent C1: Builder

Goal: Implement release manifest generation, update checker/store, Preferences
UI, and menu entry points.

Necessity gate:

- Confirm `.agents/runs/manual-update-check/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `scripts/package-release.sh`
- `.github/workflows/release.yml`
- `README.md`
- `Sources/Spill/App/UpdateChecker.swift`
- `Sources/Spill/App/UpdateCheckStore.swift`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Preferences/GeneralPreferencesSection.swift`
- `Sources/Spill/Preferences/PreferencesView.swift`
- `Sources/Spill/Preferences/PreferencesWindowController.swift`
- `Sources/Spill/Preferences/UpdatePreferencesSection.swift`
- `Tests/SpillTests/UpdateCheckerTests.swift`

Do not edit:

- `docs/index.html`
- `.agents/runs/landing-page-showcase`

Acceptance:

- Manual check fetches a static manifest and compares versions.
- Update button opens the manifest download URL only when a newer supported
  release is available.
- Release assets include `update.json`.
- No background update polling.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal: Verify behavior, release metadata, and regression gates.

Review scope:

- Update checker logic.
- Preferences/menu UI wiring.
- Release artifact manifest generation.

Checks:

- PRD alignment
- ARD alignment
- `swift test`
- `swift build`
- `./scripts/build-app.sh`
- `python3 .agents/scripts/workflow.py verify`
- permission states unchanged

Final report:

- findings first
- verification result
- residual risks
