# Agent Briefs: Menu Bar Glance Summary

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- The menu bar glance scope is CPU and memory only.
- Keep one `NSStatusItem`; do not add private menu bar APIs or spacer behavior.

## Builder

Goal: Restrict the menu bar glance summary to CPU and memory percentages, render them as compact visual chips, and preserve richer panel detail.

Write scope:

- `Sources/Spill/MenuBar/SpillMenuBarStatusItem.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`
- `Tests/SpillTests/MenuBarStatusSummaryTests.swift`

Do not edit:

- `Sources/Spill/Accessibility/`
- `Sources/Spill/Providers/SystemGPUProvider.swift`
- `Sources/Spill/Providers/LocalAIStatusProvider.swift`

Acceptance:

- Default menu bar values are CPU and memory only.
- CPU and memory render with symbols, percentage values, and usage bars in the existing status item.
- Unsupported persisted menu bar values are ignored.
- GPU, network, and AI detail popovers do not show the menu bar toggle.
- Panel status detail remains available.

Final report:

- changed files
- behavior implemented
- commands run
- residual risks

## Verifier

Goal: Confirm the menu bar summary is narrow and that the old long default cannot return from stale settings.

Checks:

- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `git diff --check`

Manual checks:

- Launch app and confirm menu bar chips use CPU and memory only.
- Open panel and confirm AI/GPU/network details remain available.
