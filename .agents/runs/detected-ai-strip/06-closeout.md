# Closeout: Detected AI Strip

## Shipped

- Local AI statuses now render only for detected or configured tools.
- Codex and Ollama show `Active` when a matching process is running.
- Codex and Ollama show `Idle` when installed but not running.
- OpenAI shows only when local OpenAI configuration is present.
- The panel omits the AI divider and section when no AI statuses are visible.

## Changed Files

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/runs/detected-ai-strip`
- `Sources/Spill/Providers/LocalAIStatusProvider.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelContentSizer.swift`
- `Sources/Spill/Panel/SpillPanelContentReport.swift`
- `Sources/Spill/Panel/SpillPanelAccessibilityReport.swift`
- `Tests/SpillTests/LocalAIStatusProviderTests.swift`
- `Tests/SpillTests/AIStatusStoreTests.swift`
- `Tests/SpillTests/SpillPanelContentReportTests.swift`
- `Tests/SpillTests/SpillPanelLayoutTests.swift`
- `Tests/SpillTests/SpillPanelAccessibilityReportTests.swift`

## Verification

- `swift test --filter LocalAIStatusProviderTests`
- `swift test --filter AIStatusStoreTests`
- `swift test --filter SpillPanelContentReportTests`
- `swift test --filter SpillPanelLayoutTests`
- `swift test --filter SpillPanelAccessibilityReportTests`
- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `./scripts/build-app.sh`
- `./scripts/verify-panel-layout-smoke.sh`

## Residual Risks

- GUI-launched apps may not inherit shell OpenAI environment variables.
- Codex and Ollama executable detection is best-effort for unusual install paths.

## Follow-up Tasks

- Keep richer AI telemetry out of Spill unless Agent Cat integration becomes a separate product decision.

## Docs Updated

- [x] PRD
- [x] ARD
- [x] feature run
