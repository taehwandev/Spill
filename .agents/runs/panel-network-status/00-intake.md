# Feature Intake

## Feature ID

`panel-network-status`

## Request

Add network status to the compact panel status section, where "network status" means current receive/upload activity rather than online/offline reachability. The panel already has system status rows and a Network module, so this slice should make Network visible as a regular panel status module and show compact traffic throughput.

## User Problem

Users need the compact panel to show how much network activity is happening right now alongside CPU, memory, and storage. Online/offline reachability is not enough because the useful question is whether the Mac is actively receiving or uploading data.

## Necessity Assessment

- Product fit: yes, because the PRD names Network as an initial system status strip metric.
- Best owner: Spill, because the compact panel owns this status composition.
- Compactness: yes, because this is one additional status row using the existing compact row pattern.
- API and distribution impact: no private API, fragile behavior, or new permission prompt.
- Cost of skipping: the panel remains inconsistent with the documented initial status scope.

Decision: `build`

Reason: The request is clear after maintainer clarification: the panel needs receive/upload throughput, not default-route availability.

## Ambiguity Gate

Use `.agents/workflows/ambiguity-gate.md` before PRD authoring.

Clarity: `clear`

Unknown classification:

- blocker: None.
- researchable: Existing status module/provider coverage, tests, and public macOS interface counters.
- assumable: Network should use the existing network status row, detail popover, preferences module behavior, and local interface byte counters.
- out-of-scope: New menu bar glance support, per-interface diagnostics, or a larger dashboard.

Resolved inputs:

- maintainer: Add network status to the panel; clarified that the status should show actual receive/upload activity, not whether the network is online.
- repo-research: `.agents/specs/prd.md` lists CPU, Memory, Battery, and Network as initial status strip metrics; `.agents/specs/ard.md` describes provider-based status models and compact panel composition.
- assumption: Aggregated non-loopback interface byte counters are the desired MVP signal.

If clarity is `needs-clarification`, ask only the blocking questions below and stop before writing `01-prd.md`.

## PRD Authoring Gate

All blocking inputs are clear: user intent, expected behavior, feature value, UI scope, feasibility, permission impact, and distribution impact.

## Clarifying Questions

Questions:

- None.

## Target User

Mac users who rely on Spill's compact panel for quick system state and need to see whether downloads, uploads, syncs, or background transfers are active.

## Proposed Product Shape

The panel status section includes a Network row with the same compact row treatment as CPU, Memory, and Storage. The row shows current receive and upload rates, opens the existing status detail popover with throughput details, and participates in the status module preferences list.

## Constraints

- macOS/public API constraints: use public local interface counters from `getifaddrs`.
- permission constraints: no new permissions.
- distribution constraints: no private API or entitlement change.
- performance constraints: refresh network only when required by visible panel or other enabled status consumers.

## Non-goals

- Per-interface throughput graphs.
- Interface picker or per-interface diagnostics.
- Enabling network as a menu bar glance in this slice.
- Redesigning the panel status section.

## Open Questions

- Later slices can decide whether network should become a supported menu bar glance item.

## Decision

Status: `accepted`

Reason: This is a small, documented, feasible panel completion slice.
