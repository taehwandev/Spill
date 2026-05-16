# Agent Briefs: Status Detail Menu Bar

## Coordination

Keep the single status item architecture. Do not add private APIs, screen capture, or another menu bar item.

## Product Architect Brief

Define the feature around two user needs: glanceable status without opening the panel, and deeper details when a panel status pill is clicked.

Deliverables:

- Intake, PRD, ARD, and task breakdown.
- Clear non-goals for private APIs and secret display.
- Verification plan covering tests, smoke checks, workflow gates, and diff whitespace.

## Builder Brief

Implement persisted menu bar status visibility, menu bar summary formatting, shared stores, refresh loop, GPU availability, and panel detail popovers.

Files:

- `Sources/Spill/Settings/SpillSettings.swift`
- `Sources/Spill/MenuBar/SpillMenuBarStatusItem.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Providers/SystemMemoryProvider.swift`
- `Sources/Spill/Providers/SystemGPUProvider.swift`
- `Sources/Spill/Providers/SystemNetworkProvider.swift`

Constraints:

- If no status values are enabled, the status item stays icon-only.
- AI output must not expose OpenAI key values.
- GPU status must stay within public Metal APIs and avoid unsupported live utilization claims.
- The panel remains compact and passes layout smoke.

## Verifier Brief

Run:

- `swift test`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py verify`
- `git diff --check`

Manual follow-up:

- In a live app session, verify each status pill popover anchors near the clicked pill.
- Confirm menu bar text remains readable with CPU and memory enabled.
