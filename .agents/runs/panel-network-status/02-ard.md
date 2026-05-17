# Detailed ARD: Panel Network Status

## Architecture Summary

The existing status architecture already contains `SpillStatusModule.network`, `SystemStatusStore.network`, presentation rows, history, and panel detail popovers. This slice promotes Network into the default panel status module set and changes `SystemNetworkProvider` from route reachability to receive/upload throughput computed from sequential local interface byte-counter samples. The compact graph keeps receive and upload as separate traces.

## Decisions

### D1: Use the existing status module architecture

Decision: Add Network to `SpillStatusModule.defaultOrder` and `primaryPanelModules`.

Rationale: The panel already renders status modules generically from `PanelState.visibleStatusModules`, and settings already persist order and enabled state based on `SpillStatusModule.defaultOrder`.

Alternatives considered: Add a one-off Network row in `SpillBarView`. Rejected because it would bypass preferences, refresh requirements, and the provider-based model.

### D2: Keep menu bar glance support unchanged

Decision: Network becomes a panel status module only in this slice.

Rationale: `SpillMenuBarStatusItem.network` currently exists but is not in `glanceSupported`; enabling menu bar network display needs separate UX and summary behavior decisions.

Alternatives considered: Enable the menu bar Network item now. Rejected as outside the user's panel request.

### D3: Compute aggregate throughput from interface counters

Decision: Use `getifaddrs` to aggregate non-loopback interface byte counters, then compute bytes per second in `SystemStatusStore` from the previous and current samples. On the first enabled refresh, the store takes a short second sample so the panel can show throughput immediately.

Rationale: Throughput requires a delta between samples. Keeping previous samples in the store avoids global provider state and keeps disabled modules from continuing to measure traffic.

Alternatives considered: Continue using default-route reachability. Rejected because the maintainer clarified the feature is about receive/upload activity, not online status.

### D4: Preserve separate receive and upload graph history

Decision: Keep the existing aggregate metric history for status semantics, and add a dedicated `SystemNetworkTrafficHistory` with separate receive and upload ratios for the Network row sparkline. In the row presentation, receive uses blue and upload uses orange across text and graph traces.

Rationale: The panel row needs to show both directions independently without adding more visible controls or expanding the row footprint.

Alternatives considered: Graph total activity only. Rejected because the maintainer clarified the graph should also distinguish receive and upload.

## Modules Affected

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

## New Types / APIs

No new public types or APIs.

```swift
static let defaultOrder: [SpillStatusModule] = [.cpu, .memory, .storage, .network]
static let primaryPanelModules: [SpillStatusModule] = defaultOrder
static func status(previous: SystemNetworkReading?, current: SystemNetworkReading?) -> SystemNetworkStatus
struct SystemNetworkTrafficHistory: Equatable, Sendable
```

## Data Flow

```text
getifaddrs counters -> SystemStatusStore previous/current sample -> SystemNetworkProvider throughput status -> SystemStatusStore receive/upload history -> SpillBarView Network row
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: unchanged.
- Network: no prompt; reads local interface counters.
- File system: unchanged.

## Failure Modes

- No interface counter sample: Network row shows unavailable.
- Missing second interface counter sample: Network row shows sampling.
- Counter reset or interface churn: provider treats the current counter as the delta to avoid negative throughput.
- Stored settings omit Network: normalization appends Network to the order.
- Stored enabled settings omit Network from before the module existed: a one-time migration enables Network and marks the migration complete.
- User disables Network after migration: visible panel modules omit Network and panel refresh requirements do not include it unless another consumer later supports it.

## Performance Notes

Adding Network to default visible modules means panel-visible refreshes will read lightweight local interface counters. The first enabled refresh reads counters twice with a short interval to avoid waiting for the next scheduled refresh. Disabled Network modules remain skipped through `statusModulesRequiredForRefresh`, and stored previous samples reset while disabled.

## Test Strategy

### Automated

- Update `SpillSettingsTests` for Network defaults, one-time migration, persistence, normalization, and refresh requirements.
- Update `PanelStoreTests` for configured visible module order including Network.
- Update `SystemNetworkProviderTests` for throughput calculation and formatting.
- Update `SystemStatusStoreTests` for previous-sample caching and separate receive/upload graph history.
- Run focused tests and full Swift test suite.

### Manual

- Build the app and verify the compact panel remains usable with the fourth status row.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| T1 module defaults | Builder | `Sources/Spill/Providers/SpillStatusModule.swift`, `Sources/Spill/Settings/SpillSettings.swift` | No |
| T2 throughput provider | Builder | `Sources/Spill/Providers/SystemNetworkProvider.swift`, `Sources/Spill/Providers/SystemStatusStore.swift`, `Sources/Spill/Panel/SpillStatusDetailModels.swift`, `Sources/Spill/Panel/SpillBarView.swift` | No |
| T3 tests | Builder | `Tests/SpillTests/SpillSettingsTests.swift`, `Tests/SpillTests/PanelStoreTests.swift`, `Tests/SpillTests/SystemNetworkProviderTests.swift`, `Tests/SpillTests/SystemStatusStoreTests.swift` | No |
| T4 verification | Verifier | `.agents/runs/panel-network-status/05-verification.md` | After T1/T2/T3 |

## Risks

- A fourth row increases panel content height. Existing scroll behavior and compact row sizing should handle this, but smoke verification should catch obvious layout regressions.
