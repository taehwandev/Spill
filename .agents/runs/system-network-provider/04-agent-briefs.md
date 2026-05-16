# Agent Briefs: System Network Provider

## Builder Brief

Goal: Add a local Network status module using public macOS reachability APIs.

Files:

- `Sources/Spill/Providers/SystemNetworkProvider.swift`
- `Sources/Spill/Providers/SpillStatusModule.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Tests/SpillTests/SystemNetworkProviderTests.swift`
- `Tests/SpillTests/SystemStatusStoreTests.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`

Acceptance:

- `SystemNetworkProvider` maps local reachability into short UI values.
- Network is part of configurable status modules.
- Disabled Network skips its provider reader.
- `swift test` passes.

Constraints:

- Do not add network calls.
- Do not use private APIs.
- Do not add permissions.

## Verifier Brief

Goal: Run repository gates and document residual risks.

Files:

- `.agents/runs/system-network-provider/05-verification.md`
- `.agents/runs/system-network-provider/06-closeout.md`
- `.agents/tasks/roadmap.yml`
- `README.md`

Acceptance:

- Workflow gates pass.
- Roadmap marks Network status done.
- Residual limits of reachability are documented.
