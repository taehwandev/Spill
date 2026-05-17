# Verification: Status Performance Optimization

## Build Checks

- [x] `swift test --filter SystemStatusStoreTests`
- [x] `swift test --filter MenuBarScanRefreshPolicyTests`
- [x] `swift test`
- [x] `./scripts/build-app.sh`
- [x] `./scripts/verify-panel-layout-smoke.sh`
- [x] `./scripts/verify-status-click-smoke.sh`
- [x] `python3 .agents/scripts/workflow.py verify`
- [x] Scoped `git diff --check` for optimization files

## Manual Checks

- [x] App launches.
- [x] Menu bar trigger is visible.
- [ ] Panel opens.
- [ ] Panel closes.

## Feature Checks

- [x] Action icon data is downsampled before storage.
- [x] Repeated action icon rendering reuses a decoded image cache.
- [x] CPU status refresh uses a stored prior reading instead of sleeping on every refresh.
- [x] First CPU refresh without a baseline stays in `Sampling`.
- [x] Unchanged menu bar status segments avoid view reinstall.
- [x] Panel open and app activation scanner requests use stale-aware refresh.
- [x] Manual refresh, workspace changes, screen changes, and stale AX references still force scan.
- [x] Unchanged scanner results skip republishing the same `items` array.

## Regression Checks

- [x] CPU core history still updates and clears when core samples disappear.
- [x] Network receive/upload histories still update.
- [x] Panel layout smoke test passes.
- [x] Status click smoke test passes.
- [x] No unrelated preferences files were edited by this run.
- [x] Relaunched `.build/Spill.app`; process confirmed as PID `35546`.
- [x] Sampled PID `35546` for 2 seconds; no dominant `PNGReadPlugin`, `AXMenuBarScanWorker`, or AX scan stack appeared.

## Notes

- First `python3 .agents/scripts/workflow.py verify` run failed because this verification file and closeout still had template placeholders. The placeholders were replaced before final verification.
- One workflow retry failed because `Sources/Spill/Preferences/PreferencesView.swift` was modified during `swift build`; a direct `swift build` and a later workflow rerun passed.
- Full `git diff --check` fails on unrelated existing Preferences changes:
  `Sources/Spill/Preferences/GeneralPreferencesSection.swift` and
  `Sources/Spill/Preferences/PreferencesView.swift`.
  Scoped diff check for this optimization slice passes.
- Post-relaunch final sample: physical footprint `143.4M`, peak `212.0M`.

## Result

Status: `pass`

Reason: Automated tests, build, workflow verification, scoped diff check, relaunch, and post-relaunch sampling passed for this optimization slice. Full diff whitespace check remains blocked by unrelated Preferences edits outside this run.
