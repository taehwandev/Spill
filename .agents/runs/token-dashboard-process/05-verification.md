# Verification: Token Dashboard Process Surface

## Build Checks

- [x] `swift test`
- [x] `./scripts/build-app.sh`
- [x] `python3 .agents/scripts/workflow.py runtime-smoke`

## Manual Checks

- [x] App launches in runtime smoke.
- [x] Dashboard helper launches in runtime smoke.
- [ ] Menu bar trigger is visible in a live GUI session.
- [ ] Manual Command-Q helper-only behavior confirmed in a live GUI session.

## Feature Checks

- [x] Helper bundle path is defined as `Spill Token Dashboard.app`.
- [x] Helper bundle id suffix is `.TokenDashboard`.
- [x] Main entry point selects `TokenMeteringDashboardAppDelegate` for the
  dashboard process.
- [x] Main app opens the helper via `TokenMeteringDashboardLauncher`.
- [x] Helper delegate avoids status item, compact panel, scanner, hotkey, bridge
  server, and ingestion setup ownership.
- [x] Helper can request the main app token metering preferences surface.
- [x] Build script packages the helper app inside the main app bundle.

## Regression Checks

- [x] No giant status item spacer.
- [x] Panel remains compact.
- [x] Token usage event schema unchanged.
- [x] Token privacy boundary unchanged.

## Notes

The automated smoke path verifies main app and helper startup/shutdown in a
bounded runtime. Full menu bar pointer behavior and Command-Q focus behavior
still require a manual GUI session check.

## Result

Status: `partial`

Reason: Automated tests and runtime smoke cover the process contract and helper
startup. Manual GUI focus behavior remains a release-risk note rather than a
source verification blocker.
