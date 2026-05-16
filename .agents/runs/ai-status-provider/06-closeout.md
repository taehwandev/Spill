# Closeout: AI Status Provider

## Shipped

- Added local AI status models and provider.
- Added `AIStatusStore`.
- Added compact AI strip pills for Codex, Ollama, and OpenAI configuration.
- Converted system status display from stacked meters to compact horizontal pills so the visual surface stays compact.
- Added tests for provider mapping, no-secret OpenAI output, and store refresh.

## Changed Files

- `.agents/runs/ai-status-provider/`
- `.agents/tasks/roadmap.yml`
- `README.md`
- `Sources/Spill/Providers/LocalAIStatusProvider.swift`
- `Sources/Spill/Providers/AIStatusStore.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Tests/SpillTests/LocalAIStatusProviderTests.swift`
- `Tests/SpillTests/AIStatusStoreTests.swift`

## Verification

- `swift test`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py verify`
- `git diff --check`

## Residual Risks

- Process-name detection is best effort.
- Apps launched from Finder may not inherit shell OpenAI environment variables.
- Manual interactive visual inspection is still pending.

## Follow-up Tasks

- Add pixel or accessibility-tree visual regression checks for status and AI rows.
- Consider a preferences toggle for the AI strip if users want to hide it.

## Docs Updated

- [x] PRD
- [x] ARD
- [x] roadmap
- [x] README
