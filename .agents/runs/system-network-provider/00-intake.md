# Intake: System Network Provider

## User Request

Continue the remaining roadmap work after the completed CPU, memory, power, and Sleep Guard slices. The next scoped system strip task is network availability.

## Necessity

### User Pain

The compact system strip should show whether the Mac has a usable default network route without making users open System Settings or a separate network utility.

### Product Fit

Yes. Network status is explicitly listed as the remaining System strip task in the roadmap.

### Spill Ownership

Yes. Spill already aggregates compact local system signals in the panel. A lightweight local route check fits that product surface and does not require network calls.

### Cost Of Skipping

The System strip milestone remains incomplete and the panel omits a basic availability signal that users expect beside CPU, memory, and power.

## Scope

- Add a local network provider using public macOS APIs.
- Add deterministic mapping tests for online, offline, connection-required, and unavailable states.
- Add Network to configurable status modules.
- Render Network in the panel status section.
- Update roadmap and closeout artifacts.

## Out Of Scope

- Wi-Fi SSID, interface name, throughput, DNS checks, latency checks, or external internet probes.
- Network calls.
- Private APIs.
- Menu bar scanner behavior.

## Decision

Decision: `build`

Reason: Network status is the last pending System strip signal and can be implemented with public local reachability APIs.

Clarification required: false

Questions: none
