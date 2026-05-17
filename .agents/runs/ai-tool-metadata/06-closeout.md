# Closeout: AI Tool Metadata

## Shipped

- Added Claude and Gemini to local AI tool detection.
- Added best-effort model metadata from visible process arguments.
- Added Ollama active model metadata from `ollama ps`.
- Added local CLI version metadata from short `--version` probes.
- Renamed OpenAI display semantics to `OpenAI API` and limited model hints to explicit OpenAI environment keys.
- Added model, version, and source rows to AI detail popovers.

## Changed Files

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/runs/ai-tool-metadata`
- `Sources/Spill/Providers/LocalAIStatusProvider.swift`
- `Sources/Spill/Panel/SpillStatusDetailModels.swift`
- `Tests/SpillTests/LocalAIStatusProviderTests.swift`
- `Tests/SpillTests/SpillStatusDetailRowsTests.swift`
- `Tests/SpillTests/SpillPanelAccessibilityReportTests.swift`

## Verification

- `swift test --filter LocalAIStatusProviderTests`
- `swift test --filter SpillStatusDetailRowsTests`
- `swift test --filter SpillPanelAccessibilityReportTests`
- `swift test --filter AIStatusStoreTests`
- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `./scripts/build-app.sh`

## Residual Risks

- Exact AI session model is unavailable when the CLI does not expose it in process arguments.
- GUI-launched Spill may not see every shell-only executable path.
- CLI `--version` output formats may change.

## Follow-up Tasks

- Consider an Agent Cat integration only as a separate product decision.

## Docs Updated

- [x] PRD
- [x] ARD
- [x] feature run
