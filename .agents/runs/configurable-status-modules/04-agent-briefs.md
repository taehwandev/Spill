# Agent Briefs: Configurable Status Modules

## Coordination Rules

- Ask the maintainer before expanding scope beyond CPU and memory compact meters.
- Keep all repository documentation and code comments in English.
- Do not use private APIs or status item spacer behavior.
- Disabled modules must not run provider readers.
- Preserve compact panel height.

## Agent A: Settings Model

Goal: Add the typed module model and persistent settings API.

Write scope:

- `Sources/Spill/Providers/SpillStatusModule.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`

Acceptance:

- Default order is CPU then memory.
- Default enabled set includes all known compact status modules.
- Persisted order ignores unknown and duplicate IDs.
- Tests cover enable, disable, and move behavior.

## Agent B: Store And Panel Wiring

Goal: Make the store and panel obey enabled modules and configured ordering.

Write scope:

- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Tests/SpillTests/SystemStatusStoreTests.swift`

Acceptance:

- CPU is integrated into the cached store.
- CPU sampling uses async refresh.
- Disabled CPU and memory readers do not run.
- The panel renders enabled meters in configured order.

## Agent C: Preferences UI

Goal: Add simple controls for status module visibility and order.

Write scope:

- `Sources/Spill/Preferences/StatusModulesPreferencesSection.swift`
- `Sources/Spill/Preferences/PreferencesView.swift`

Acceptance:

- Preferences shows CPU and memory rows.
- Each row has an on/off toggle.
- Each row has up/down icon reorder controls.

## Agent D: Verifier

Goal: Verify the slice and update closeout documentation.

Write scope:

- `.agents/runs/configurable-status-modules/05-verification.md`
- `.agents/runs/configurable-status-modules/06-closeout.md`
- `.agents/tasks/roadmap.yml`

Commands:

- `swift build`
- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py run-gates`
- `python3 .agents/scripts/workflow.py language-gates`
- `python3 .agents/scripts/workflow.py code-gates`

Acceptance:

- All automated gates pass.
- Residual risks are documented.
