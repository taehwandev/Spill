# Agent Briefs: Detected AI Strip

## Builder Brief

Goal: make the existing AI strip optional and detection-based without adding
network calls, new permissions, or Agent Cat integration.

Implementation constraints:

- Keep the provider local-only.
- Preserve secret-safe OpenAI output.
- Do not edit the unrelated Preferences Agent Cat promo work in this slice.
- Hide missing AI providers instead of showing unavailable placeholder pills.

Expected files:

- `Sources/Spill/Providers/LocalAIStatusProvider.swift`
- `Sources/Spill/Providers/AIStatusStore.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelContentSizer.swift`
- `Sources/Spill/Panel/SpillPanelContentReport.swift`
- `Sources/Spill/Panel/SpillPanelAccessibilityReport.swift`
- Matching focused tests under `Tests/SpillTests`.

Verification:

- Focused provider and panel tests.
- Full `swift test` after integration.
- Panel layout smoke because visible section count and preferred height change.
