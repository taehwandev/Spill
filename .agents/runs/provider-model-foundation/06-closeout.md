# Closeout: Provider Model Foundation

## Shipped

- Plain `SpillProviderID` model.
- Plain `SpillStatusItem` model.
- Plain `SpillAction` model.
- Status provider protocol.
- Action provider protocol.
- Action execution protocol.
- Provider model unit tests.
- No visible UI behavior change.

## Changed Files

- `Package.swift`
- `Sources/Spill/Providers/SpillStatusModels.swift`
- `Sources/Spill/Providers/SpillActionModels.swift`
- `Tests/SpillTests/SpillProviderModelsTests.swift`
- `.agents/runs/provider-model-foundation/`
- `.agents/specs/ard.md`
- `.agents/workflows/implementation.md`
- `.agents/checklists/review.md`

## Verification

- `swift build`
- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py runtime-smoke`

## Residual Risks

- Protocol actor isolation may need adjustment once real providers are implemented.
- Action identity may need richer namespacing when multiple providers contribute actions.
- UI mapping is intentionally deferred until the Stitch/UI design is defined.

## Follow-up Tasks

- Add placeholder provider implementations that return deterministic sample values.
- Add an adapter from existing selected menu bar snapshots to `SpillAction`.
- Define panel UI in Stitch before rendering provider data.
- Add real system status, AI status, and window action providers behind the shared protocols.

## Docs Updated

- PRD: yes.
- ARD: yes.
- roadmap: no.
- README: no.
