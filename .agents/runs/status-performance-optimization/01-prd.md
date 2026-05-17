# Detailed PRD: Status Performance Optimization

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, clarity is `clear`, and no maintainer clarification is required.

## Summary

Reduce Spill's status and panel overhead without changing visible behavior. Optimize repeated menu bar/app icon decoding, CPU sampling latency, menu bar status view churn, and menu bar scanner reloads during trigger clicks.

## Goals

- Keep panel and menu bar status behavior visually unchanged.
- Reduce repeated `NSImage(data:)` and PNG decoding work for app icons.
- Remove the recurring 0.5 second CPU sampling sleep from normal status refresh.
- Avoid rebuilding menu bar chip views when the status segment model has not changed.
- Avoid full AX menu bar rescans on ordinary panel open or app activation when cached scan results are still fresh.
- Preserve conservative polling and public API usage.

## Non-goals

- Add new UI.
- Change status module semantics.
- Change AX scanner coverage.
- Change explicit manual refresh behavior.
- Add private APIs or new permissions.
- Replace the panel architecture.

## User Stories

- As a user, I want opening Spill to feel quick even after menu bar item scanning has icons.
- As a user, I want status polling to keep updating without making the menu bar feel busy.
- As a user, I want CPU status to update without a built-in half-second wait per refresh.
- As a user, I want clicking the Spill trigger to show the cached panel immediately instead of reloading menu bar items every time.

## UX Requirements

- Menu bar trigger and status chips remain visually equivalent.
- Panel action icons still show app icons when available.
- CPU, memory, storage, network, power, AI, and window action states remain unchanged.
- If optimized icon rendering fails, existing symbol fallback should still work.

## Behavior Scenarios

### Icon Cache

Given scanned menu bar items include app icon data
When the panel renders action buttons repeatedly
Then the app reuses decoded icon images instead of decoding the same data on every body calculation.

### CPU Sampling

Given at least one prior CPU reading has been captured
When status refresh runs
Then CPU usage is computed from the previous and current readings without sleeping inside the refresh.

Given no prior CPU reading exists
When status refresh runs
Then CPU status can show `Sampling` and stores the first reading for the next refresh.

### Menu Bar Status

Given menu bar status segments are unchanged
When `StatusItemController.refresh()` runs
Then it avoids reinstalling the status content subviews.

Given status segment values change
When `StatusItemController.refresh()` runs
Then it updates the status item presentation as before.

### Menu Bar Scanner Cache

Given a recent menu bar scan exists
When the user opens the panel or Spill becomes active
Then Spill should reuse the cached scan result and avoid a full AX scan.

Given the scan result is stale or missing
When the user opens the panel
Then Spill can show the cached panel immediately and refresh menu bar items asynchronously.

Given the user chooses Refresh or the workspace/screen configuration changes
When a scan is requested
Then Spill should force a full scan.

Given a stored AX reference fails during a menu bar action
When the action fails
Then Spill should schedule a forced rescan to repair stale references.

## Functional Requirements

1. Icon image decoding must be cached by icon data identity/content.
2. Scanner icon data should be downsampled before PNG encoding to avoid large retained icon payloads.
3. `SystemStatusStore` must preserve previous CPU readings and use them for delta calculation.
4. CPU refresh must not call the async two-sample `SystemCPUProvider.status()` path in the default store refresh.
5. Menu bar status content should be reinstalled only when segments change.
6. Panel open and app activation scanner requests must use stale-aware refresh instead of unconditional full scans.
7. Manual Refresh, workspace changes, and screen changes must continue to force scan.
8. Scanner result publishing should skip assigning unchanged `items` so dependent stores do not redraw unnecessarily.
9. Existing tests must continue to pass, with new focused tests for CPU cached sampling and scanner refresh policy behavior where practical.

## Acceptance Criteria

- `swift test` passes.
- `./scripts/build-app.sh` passes.
- Panel layout smoke passes.
- Workflow verification passes.
- App launches after optimization.
- No changes to user-facing status labels except normal live values.
- Repeated trigger clicks within the freshness interval do not start full AX scans.

## Rollout

- MVP: icon cache/downsample, CPU previous-reading refresh, status item segment diffing, stale-aware AX scanner refresh.
- Later: deeper instrumentation and broader snapshot batching if necessary.
