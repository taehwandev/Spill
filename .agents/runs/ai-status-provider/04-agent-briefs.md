# Agent Briefs: AI Status Provider

## Builder Brief

Goal: Add a compact local AI status strip for Codex, Ollama, and OpenAI configuration.

Files:

- `Sources/Spill/Providers/LocalAIStatusProvider.swift`
- `Sources/Spill/Providers/AIStatusStore.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Tests/SpillTests/LocalAIStatusProviderTests.swift`
- `Tests/SpillTests/AIStatusStoreTests.swift`

Acceptance:

- AI statuses are local-only and deterministic in tests.
- Missing tools are quiet grey states.
- OpenAI config status does not expose secret values.
- Panel remains compact.

## Verifier Brief

Goal: Run gates, update roadmap, and document residual risks.

Files:

- `.agents/runs/ai-status-provider/05-verification.md`
- `.agents/runs/ai-status-provider/06-closeout.md`
- `.agents/tasks/roadmap.yml`
- `README.md`

Acceptance:

- `swift test` passes.
- Workflow gates pass.
- Panel layout smoke passes.
