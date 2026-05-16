# Closeout: Pinned Actions UI

## Shipped

- Pinned menu bar items render before non-pinned action items in the existing compact action row.
- Each action tile includes a compact pin or unpin control.
- Disabled action execution no longer disables the pin toggle.
- Action clicks show success or failure feedback in the header subtitle.
- Successful action clicks dismiss the panel after a short delay.
- Menu bar action metadata now carries the source bundle identifier.
- Stale AXPress failures can fall back to activating or opening the source app with public `NSWorkspace` APIs.

## Files

- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Providers/SpillActionModels.swift`
- `Sources/Spill/Providers/MenuBarActionAdapter.swift`
- `Tests/SpillTests/MenuBarActionAdapterTests.swift`
- `.agents/runs/pinned-actions-ui/`
- `.agents/tasks/roadmap.yml`
- `README.md`

## Verification

- `swift test` passed.
- `python3 .agents/scripts/workflow.py panel-layout-smoke` passed.
- `python3 .agents/scripts/workflow.py runtime-smoke` passed.
- `python3 .agents/scripts/workflow.py verify` passed.
- `git diff --check` passed.

## Residual Risk

- App activation fallback can only open or activate the source app. It cannot guarantee the original stale menu bar extra command is executed.
- Manual visual confirmation is still useful because live menu bar item availability depends on the user's current apps and Accessibility permission.
