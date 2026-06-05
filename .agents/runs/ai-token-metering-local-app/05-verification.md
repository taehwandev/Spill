# Verification: AI Token Metering Local App Bridge

## Build Checks

- [x] `swift test` - passed; 262 tests.
- [x] `./scripts/build-app.sh` - passed; built `.build/Spill.app`.
- [x] `./scripts/verify-status-click-smoke.sh` - passed; menu bar status
  item primary click opened the existing Spill Panel.
- [x] `npm test` from `web/` - passed; 4 sync-safe sanitizer tests.
- [x] `npm run build` from `web/` - passed.
- [x] `git diff --check` - passed.
- [x] `npx --yes @taehwandev/vibeguard audit . --rules /Users/taehwankwon/Documents/KeyFlowVault/AgentPlaybook` - passed; Overall Ready, no findings.

## Manual Checks

- [x] Existing Spill process was stopped and the newly built `.build/Spill.app/Contents/MacOS/Spill` was started.
- [x] `curl -sS http://127.0.0.1:48731/v1/usage/health` returned `{"status":"ok","source":"spill_local_app"}`.
- [x] `curl -sS http://127.0.0.1:48731/v1/usage/events` returned an empty schema-versioned safe envelope.
- [x] Web dev server is responding at `http://127.0.0.1:5173/` for the cloud dashboard preview only.

## Feature Checks

- [x] App startup initializes a local-only token usage bridge unless `SPILL_TOKEN_USAGE_BRIDGE_DISABLED=1` is set.
- [x] Bridge binds to `127.0.0.1` instead of accepting network-interface traffic.
- [x] Bridge exposes health, read, append, and clear endpoints.
- [x] Bridge rejects unknown and forbidden content-like fields.
- [x] Native app local dashboard aggregates the app-owned token store without a browser or web server.
- [x] Preferences exposes Token Metering with local-only active, cloud aggregate requiring login plus explicit enablement, and cloud detailed requiring a separate token-only opt-in.
- [x] Status menu and app menu open the native local token dashboard without adding upload code.
- [x] Menu bar primary click keeps opening the existing Spill Panel.
- [x] The existing Spill Panel AI section shows local token metering summary.
- [x] Web dashboard is presented as cloud preview, not the installed local dashboard.

## Regression Checks

- [x] No prompt text, command text, file path, terminal output, diff, log body, source content, environment value, or secret is accepted by the usage event sanitizer.
- [x] `TokenUsageStoreTests.testBridgeStartBindsLoopbackHTTPPort` verifies the actual loopback HTTP listener.
- [x] `TokenUsageStoreTests.testPreferencesModelSeparatesLocalAndCloudOptInModes` verifies the local/login/cloud detailed state contract.
- [x] `TokenUsageStoreTests.testDashboardSnapshotAggregatesLocalEvents` verifies app local dashboard aggregation.
- [x] App survives bridge startup errors instead of crashing.

## Notes

- The first `NWListener` implementation failed at runtime with `EINVAL` when forced to `127.0.0.1`; it was replaced with a POSIX loopback socket server to preserve the local-only boundary.
- The local app process is intentionally left running so the native local dashboard and bridge can be checked immediately.

## Result

Status: `pass`

Reason:

Swift tests, web tests, web build, app bundle build, VibeGuard, and live loopback bridge smoke all passed.
