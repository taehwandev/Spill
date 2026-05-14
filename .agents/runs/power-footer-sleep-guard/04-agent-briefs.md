# Agent Briefs: Power Footer And Sleep Guard

## Coordination Rules

- Keep Sleep Guard off by default.
- Do not add another macOS status item.
- Use public IOKit power assertion APIs only.
- Do not add indefinite mode in this slice.
- Ask the maintainer before adding custom duration, scheduling, or automation.

## Agent A: Settings

Goal: Add user preferences for power footer visibility and display-awake behavior.

Write scope:

- `Sources/Spill/Settings/SpillSettings.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`

Acceptance:

- `showPowerFooter` defaults to true.
- `sleepGuardKeepsDisplayAwake` defaults to false.
- Persistence is covered by tests.

## Agent B: Sleep Guard Controller

Goal: Implement time-based sleep prevention with injectable assertion management.

Write scope:

- `Sources/Spill/App/SleepGuardController.swift`
- `Tests/SpillTests/SleepGuardControllerTests.swift`

Acceptance:

- Controller starts off.
- Starting creates a system idle sleep assertion.
- Display assertion is optional and rolls back on failure.
- Stop and expiry release all assertions.

## Agent C: UI Wiring

Goal: Add compact panel and Preferences UI.

Write scope:

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Preferences/PowerPreferencesSection.swift`
- `Sources/Spill/Preferences/PreferencesView.swift`

Acceptance:

- Footer shows a Sleep Guard menu.
- Active Sleep Guard displays remaining time.
- Power footer obeys the setting.
- App termination stops Sleep Guard.

## Agent D: Verifier

Goal: Run gates, update roadmap, and document residual risks.

Write scope:

- `.agents/runs/power-footer-sleep-guard/05-verification.md`
- `.agents/runs/power-footer-sleep-guard/06-closeout.md`
- `.agents/tasks/roadmap.yml`

Commands:

- `swift build`
- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py panel-open-smoke`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`

Acceptance:

- All automated gates pass.
- Residual risks are documented.
