# Verification: CPU Core Chart Toggle

## Build Checks

- [x] `swift test --filter SystemCPUProviderTests`
- [x] `swift test --filter SpillSettingsTests`
- [x] `swift test --filter SystemStatusStoreTests`
- [x] `swift test --filter MenuBarStatusSummaryTests`
- [x] `swift test`
- [x] `./scripts/build-app.sh`
- [x] `./scripts/verify-panel-layout-smoke.sh`
- [x] `python3 .agents/scripts/workflow.py verify`
- [x] `git diff --check`

## Manual Checks

- [x] App launches.
- [x] Preferences shows CPU core bars toggle.
- [x] Panel opens.
- [x] CPU row remains compact.
- [x] CPU core bars toggle changes the CPU chart presentation when core data exists.

## Feature Checks

- [x] CPU core bars mode defaults off.
- [x] CPU core bars mode persists.
- [x] CPU status computes per-core ratios.
- [x] CPU status store keeps bounded per-core history.
- [x] CPU row falls back to aggregate sparkline when core data is unavailable.
- [x] CPU core bars clear stale core history when core samples disappear.
- [x] CPU sampling does not display measured `0%`.
- [x] Tiny non-zero CPU usage does not round to `0%`.

## Regression Checks

- [x] No giant status item spacer.
- [x] Panel remains compact.
- [x] Existing aggregate CPU value remains available.
- [x] Existing menu bar CPU/memory summary remains available.

## Notes

- `SystemCPUProviderTests` passed: 12 tests.
- `SpillSettingsTests` passed: 22 tests.
- `SystemStatusStoreTests` passed: 6 tests.
- `MenuBarStatusSummaryTests` passed: 6 tests.
- Full `swift test` passed: 147 tests.
- Build script passed and produced `.build/Spill.app`.
- Panel layout smoke passed.
- Workflow verification and diff whitespace checks passed.

## Result

Status: `pass`

Reason: CPU core bars mode is implemented behind a persisted Preferences toggle, per-core ratios and bounded history are tested, CPU zero display is clarified, and full build/test/workflow verification passed.
