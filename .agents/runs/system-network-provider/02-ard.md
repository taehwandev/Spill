# ARD: System Network Provider

## Architecture

Add `SystemNetworkProvider` beside the existing system providers. The provider reads local reachability flags for the zero IPv4 address through `SCNetworkReachabilityCreateWithAddress` and `SCNetworkReachabilityGetFlags`. This checks whether the system has a default route without sending traffic.

## API Choice

Decision: Use `SystemConfiguration` reachability.

Rationale:

- It is a public macOS framework.
- It is local and synchronous.
- It does not require Accessibility, Location, network probes, or private APIs.
- It is sufficient for coarse availability.

## Data Model

`SystemNetworkReading` stores normalized booleans:

- `isReachable`
- `connectionRequired`
- `canConnectAutomatically`
- `interventionRequired`

`SystemNetworkStatus` stores UI-ready state:

- `value`
- `subtitle`
- `availabilityRatio`
- `state`
- `symbolName`
- `isAvailable`

## Mapping

- `nil` reading -> `N/A`, unavailable.
- usable route -> `Online`, normal.
- reachable but connection required -> `Standby`, active.
- not reachable -> `Offline`, warning.

## Integration

- Add `.network` to `SpillStatusModule`.
- Add `network` and `networkReader` to `SystemStatusStore`.
- Render `.network` in `SpillBarView.statusMeter`.
- Update `SpillSettingsTests` for the new default module order.
- Add provider and store tests.

## Risks

- Reachability reports route availability, not guaranteed internet access.
- Captive portals and DNS failures can still show `Online`.
- Some interface-specific states are intentionally hidden in this MVP.

## Verification

- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`
- `python3 .agents/scripts/workflow.py runtime-smoke`
