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

- At this slice's original closeout, Network remained panel-only; the separate
  menu bar UX decision was resolved in the 2026-07-14 follow-up below.
- Existing user settings that have explicitly disabled modules will continue to honor those stored preferences.
- The row reports aggregate non-loopback interface activity, not per-interface diagnostics.

## Follow-up Tasks

- [x] Add Network as a default-off menu bar glance with mutually exclusive
  receive/upload Text and distinct RX/TX Chart presentations.

## Follow-up Resolution (2026-07-14)

- Network is now included in the supported clock-area status set but remains
  disabled by default.
- The menu bar reuses the panel's receive/upload histories and shared refresh
  cadence rather than starting another sampler.
- CPU, memory, and Network now expose independent Off, Text, or Chart settings;
  existing global Text/Chart choices migrate to each metric.
- Chart mode replaces numeric values with a framed chart, uses visible guides
  and fills, and works in both horizontal and vertical layouts.

## Docs Updated

- [x] PRD
- [x] ARD
- [ ] roadmap
- [x] README
