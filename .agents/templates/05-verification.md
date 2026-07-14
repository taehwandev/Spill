# Verification: <Feature Name>

## Build Checks

- [ ] `swift build`
- [ ] `./scripts/build-app.sh`

## Manual Checks

- [ ] App launches.
- [ ] Menu bar trigger is visible.
- [ ] Panel opens.
- [ ] Panel closes.
- [ ] Permission-required states are clear.
- [ ] Failure states are visible.

## Feature Checks

- [ ] 

## Settings And Surface Propagation

Complete when the feature changes settings or user-visible configuration.

- [ ] Persistence, default, and migration behavior match the PRD/ARD.
- [ ] The writer triggers the documented same-process or cross-process propagation path.
- [ ] Every affected receiving process reloads or invalidates the setting within the documented latency.
- [ ] Preferences reflects the saved state.
- [ ] Compact Spill Panel / general dashboard reflects the change when applicable.
- [ ] Separate AI Token Metering dashboard helper reflects the change when applicable.
- [ ] Clock-adjacent AI menu-bar glance reflects the change when applicable.
- [ ] Other dashboard, menu-bar, web, sync, upload, or agent-facing surfaces match the impact map.
- [ ] `Not applicable` surfaces remain unaffected for the documented reason.
- [ ] No duplicate polling timer, collector, network request, or upload-sync dependency was introduced.

## Regression Checks

- [ ] No giant status item spacer.
- [ ] Panel remains compact.
- [ ] No unrelated preferences regressions.

## Notes

## Result

Status: `pass | fail | partial`

Reason:
