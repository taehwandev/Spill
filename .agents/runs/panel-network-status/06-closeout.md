# Closeout: Panel Network Status

## Shipped

- Network is now part of the default panel status module order and is enabled by default.
- Network reports receive and upload rates from local interface byte-counter deltas instead of online/offline reachability.
- Network graphs receive and upload as separate compact traces in the status row, with matching receive/upload text colors.
- First enabled refresh takes a short second sample so the panel does not wait for the next scheduled refresh to show throughput.
- Older enabled-module preferences migrate Network on once, while later user disablement stays respected.
- Network uses the existing panel status row, status detail popover, preferences, and refresh requirement flow.

## Changed Files

- `Sources/Spill/Providers/SpillStatusModule.swift`
- `Sources/Spill/Providers/SystemNetworkProvider.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Panel/SpillStatusDetailModels.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`
- `Tests/SpillTests/PanelStoreTests.swift`
- `Tests/SpillTests/SystemNetworkProviderTests.swift`
- `Tests/SpillTests/SystemStatusStoreTests.swift`
- `.agents/runs/panel-network-status/*`

## Verification

- `swift test --filter SpillSettingsTests`
- `swift test --filter PanelStoreTests`
- `swift test --filter SystemNetworkProviderTests`
- `swift test --filter SystemStatusStoreTests`
- `swift test`
- `./scripts/build-app.sh`
- `python3 .agents/scripts/workflow.py verify`
- `./scripts/verify-panel-layout-smoke.sh`

## Residual Risks

- Network remains panel-only in this slice; menu bar network glance support still needs a separate UX decision.
- Existing user settings that have explicitly disabled modules will continue to honor those stored preferences.
- The row reports aggregate non-loopback interface activity, not per-interface diagnostics.

## Follow-up Tasks

- Decide separately whether Network should become a supported menu bar glance item.

## Docs Updated

- [x] PRD
- [x] ARD
- [ ] roadmap
- [ ] README
