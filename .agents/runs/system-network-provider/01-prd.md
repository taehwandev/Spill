# PRD: System Network Provider

## Summary

Add a compact Network status module to Spill. The module reports whether the Mac has a usable default network route using local macOS reachability state, without contacting external services.

## Goals

- Show Network availability in the compact status section.
- Keep the provider local, fast, and dependency-free.
- Let users enable, disable, and reorder Network with the existing status module preferences.
- Preserve deterministic provider mapping tests.

## Non-Goals

- Do not show SSID, interface type, IP address, VPN name, latency, bandwidth, or packet loss.
- Do not call external hosts.
- Do not add new permissions.
- Do not change menu bar item detection.

## User Stories

- As a user, I can glance at Spill and see whether network routing is available.
- As a user, I can hide Network if I do not care about it.
- As a user, I can reorder Network relative to CPU and Memory.

## Requirements

1. Add a `SystemNetworkProvider`.
2. Use a public local macOS reachability API.
3. Map reachable default route to `Online`.
4. Map missing route to `Offline`.
5. Map readable but connection-required route to a short intermediate state.
6. Map unreadable state to `N/A`.
7. Add Network to `SpillStatusModule.defaultOrder`.
8. Skip the network reader when the Network module is disabled.
9. Add unit tests for mapping and store refresh behavior.

## Acceptance Criteria

- Network appears as a configurable compact status module.
- Disabled Network does not run the network reader during status refresh.
- `swift test` passes.
- `python3 .agents/scripts/workflow.py verify` passes.
