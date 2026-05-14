# Agent Briefs: Panel Fallback Launcher

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside the assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Ask the maintainer if fallback scope, app menu behavior, or distribution impact becomes unclear.
- Do not add a second status item, private API, or floating launcher.

## Agent A: Product

Goal:

Document a visible fallback path for opening the panel without relying only on the menu bar status item.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/panel-fallback-launcher/00-intake.md`
- `.agents/runs/stitch-panel-shell/06-closeout.md`

Output:

- `.agents/runs/panel-fallback-launcher/01-prd.md`

## Agent B: Architecture

Goal:

Define how preferences and the app menu call the existing panel controller path.

Inputs:

- `.agents/runs/panel-fallback-launcher/01-prd.md`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Preferences/`

Output:

- `.agents/runs/panel-fallback-launcher/02-ard.md`
- `.agents/runs/panel-fallback-launcher/03-task-breakdown.yml`

## Agent C1: App Builder

Goal:

Add app menu commands and an explicit show-panel path in `AppDelegate`.

Necessity gate:

- Confirm `.agents/runs/panel-fallback-launcher/00-intake.md` has a `build` decision.

Write scope:

- `Sources/Spill/App/AppDelegate.swift`

Do not edit:

- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Accessibility/`

Acceptance:

- App menu commands exist.
- Show command opens the existing panel.
- Refresh and preferences commands use existing paths.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Preferences Builder

Goal:

Add compact fallback controls to preferences.

Write scope:

- `Sources/Spill/Preferences/PreferencesView.swift`
- `Sources/Spill/Preferences/PreferencesWindowController.swift`
- `Sources/Spill/Preferences/PanelFallbackPreferencesSection.swift`

Do not edit:

- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Providers/`

Acceptance:

- Open Panel button exists.
- Refresh button respects Accessibility and scanner state.
- Accessibility state appears as compact state, not long tutorial copy.

## Agent C3: Verifier

Goal:

Run automated verification and record remaining manual gaps.

Review scope:

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Preferences/`
- `.agents/runs/panel-fallback-launcher/`

Checks:

- PRD alignment
- ARD alignment
- build
- tests
- workflow gates
- runtime smoke

Final report:

- findings first
- verification result
- residual risks
