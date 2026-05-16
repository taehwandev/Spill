# Closeout: System Network Provider

## Shipped

- Added `SystemNetworkProvider` backed by public `SystemConfiguration` reachability.
- Added `SystemNetworkReading` and `SystemNetworkStatus`.
- Added Network to configurable status modules.
- Wired Network through `SystemStatusStore` and the compact panel status section.
- Added tests for online, automatic connection, standby, offline, unavailable, status item metadata, settings defaults, and disabled-reader behavior.

## Changed Files

- `.agents/runs/system-network-provider/`
- `.agents/tasks/roadmap.yml`
- `README.md`
- `Sources/Spill/Providers/SystemNetworkProvider.swift`
- `Sources/Spill/Providers/SpillStatusModule.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Tests/SpillTests/SystemNetworkProviderTests.swift`
- `Tests/SpillTests/SystemStatusStoreTests.swift`
- `Tests/SpillTests/SpillSettingsTests.swift`

## Verification

- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `git diff --check`

## Residual Risks

- Reachability reports local route availability, not guaranteed internet access.
- Captive portals, DNS failures, or blocked destinations can still show `Online`.
- Manual interactive panel inspection is still pending, though automated panel layout smoke passed.

## Follow-up Tasks

- Add pixel or accessibility-tree visual regression checks for compact status rows.
- Decide whether Network should later expose interface details in a non-compact view.

## Docs Updated

- [x] PRD
- [x] ARD
- [x] roadmap
- [x] README
