# Detailed ARD: Status Performance Optimization

## Architecture Summary

Optimize existing providers and AppKit bridge controllers in place. Keep SwiftUI view behavior unchanged while reducing repeated icon decode work, CPU sampling latency, menu bar status subview churn, and avoidable AX menu bar rescans.

## Decisions

### D1: Cache decoded icon images behind a small provider

Decision: Add an image cache that maps icon `Data` to decoded `NSImage` instances.

Rationale: Sampling showed ImageIO PNG decoding during rendering. The same app icon data can be reused across panel renders and action button body recomputation.

Alternatives considered: Store `NSImage` directly in `MenuBarItemSnapshot`. Rejected because snapshots are plain value models and currently use `Data`.

### D2: Downsample icon PNG data at scan time

Decision: Encode a small PNG representation suitable for panel icons instead of retaining full app icon representations.

Rationale: The panel only displays small icons. Large icon payloads increase decode cost and memory footprint.

Alternatives considered: Keep full icon data and rely only on decoded cache. Rejected because sample peak memory was high and full payloads remain expensive.

### D3: Move CPU refresh to previous/current store sampling

Decision: `SystemStatusStore` stores the previous CPU reading and computes status from one current reading per refresh.

Rationale: The existing async CPU provider path sleeps 0.5 seconds and reads twice per refresh. Store-owned previous/current sampling matches the network provider pattern and avoids refresh latency.

Alternatives considered: Reduce the sleep interval. Rejected because it still blocks refresh and can make CPU readings noisier.

### D4: Diff menu bar status segments before rebuilding views

Decision: `StatusItemController` skips status content view replacement when segments are equal.

Rationale: The controller runs on a polling loop; rebuilding AppKit subviews and constraints every tick is unnecessary when values do not change.

Alternatives considered: Convert menu bar chips to a fully mutable view model. Deferred because segment diffing is smaller and lower risk.

### D5: Use stale-aware scanner refresh for non-manual triggers

Decision: Keep `AXMenuBarItemScanner.refresh()` as a force refresh for explicit user refreshes, and add `refreshIfStale(reason:minimumRefreshInterval:)` for panel open, app activation, and timer-driven refreshes.

Rationale: AX menu bar scanning is best-effort and can be expensive. Opening the panel should render cached state immediately and only refresh asynchronously when the prior scan is stale. Manual refresh and OS topology changes should still force a scan.

Alternatives considered: Disable automatic scanner refresh entirely. Rejected because workspace and screen changes should still repair stale inventory without requiring user action.

## Modules Affected

- `Sources/Spill/MenuBar/MenuBarItemImageProvider.swift`
- `Sources/Spill/MenuBar/MenuBarItemSnapshot+Image.swift`
- `Sources/Spill/Panel/SpillActionViews.swift`
- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/MenuBar/AXMenuBarItemScanner.swift`
- `Sources/Spill/MenuBar/MenuBarScanCoordinator.swift`
- `Sources/Spill/App/AppDelegate.swift`
- `Tests/SpillTests/SystemStatusStoreTests.swift`
- `Tests/SpillTests/MenuBarScanRefreshPolicyTests.swift`

## Data Flow

```text
AX scan -> small icon PNG data -> decoded image cache -> panel action icon

current CPU reading + previous CPU reading in SystemStatusStore
  -> SystemCPUProvider.status(previous:current:)
  -> SystemStatusStore published status

status store/menu bar settings
  -> MenuBarStatusSummary segments
  -> StatusItemController segment diff
  -> reuse existing chip view if unchanged

panel open/app activation/timer
  -> AXMenuBarItemScanner.refreshIfStale
  -> skip full AX scan while cached results are fresh

manual refresh/workspace change/screen change/stale AX reference
  -> AXMenuBarItemScanner.refresh(force: true)
  -> full AX scan
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: unchanged.
- Network: unchanged.
- File system: unchanged.

## Failure Modes

- Icon downsample fails: fall back to no icon data and existing symbol rendering.
- CPU first sample: display sampling state until a second sample is available.
- CPU counter failure: preserve existing unavailable behavior.
- Segment diff false positive risk: `MenuBarStatusSegment` is `Equatable`, so equal segments should be visually equivalent.
- Scanner cache stale risk: workspace/screen changes and failed AX references force refresh; panel open and activation use a conservative freshness interval.

## Performance Notes

Expected wins:

- Less ImageIO/CoreGraphics work during panel renders.
- Lower icon memory footprint.
- CPU refresh avoids half-second sampling wait after the first sample.
- Menu bar status refresh avoids repeated subview/constraint churn when unchanged.
- Panel trigger clicks avoid unconditional AX scans while cached results are fresh.
- Unchanged scan results update AX references without republishing identical item arrays.

## Test Strategy

- Add or update store tests for previous CPU reading behavior.
- Add scanner refresh policy tests.
- Run focused `SystemStatusStoreTests`.
- Run full `swift test`.
- Run build, panel layout smoke, workflow verify, and whitespace check.
