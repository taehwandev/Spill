# Closeout: Token Dashboard Process Surface

## Shipped

- Added a bundled `Spill Token Dashboard.app` helper surface for the detailed
  local token dashboard.
- Routed main app dashboard entry points through a helper launcher with
  in-process fallback.
- Kept the main Spill app responsible for menu bar presence, compact panel,
  preferences, update wiring, adapter setup, and token ingestion.
- Kept the helper process limited to dashboard window/state ownership and local
  token store reads.
- Added runtime smoke support for the dashboard helper.

## Changed Files

- `Sources/Spill/App/SpillMain.swift`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardProcess.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardLauncher.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardAppDelegate.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardWindowController.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `scripts/build-app.sh`
- `scripts/verify-runtime-smoke.sh`
- `Tests/SpillTests/TokenUsageStoreTests.swift`

## Verification

- `swift test`
- `./scripts/build-app.sh`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `codesign --verify --deep --strict --verbose=2 .build/Spill.app`

## Residual Risks

- Manual GUI confirmation is still useful for Command-Q focus behavior and
  pointer-triggered AI glance behavior.
- Future cloud dashboard work must remain separate from this local helper and
  must not weaken the token-only privacy boundary.

## Follow-up Tasks

- Add a dedicated GUI smoke check for helper Command-Q behavior if the test
  harness can safely drive focused app menus.
- Keep helper packaging checks in release verification after signing or
  notarization changes.

## Docs Updated

- [x] PRD
- [x] ARD
- [x] task breakdown
- [x] verification
- [x] closeout
