# Detailed PRD: Panel Network Status

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, clarity is `clear`, and no maintainer clarification is required.

## Summary

Add Network to the compact panel's system status section so the panel shows current receive/upload activity alongside CPU, Memory, and Storage. The feature should use the existing status row, history, and detail popover patterns, and it should remain configurable through the existing status module preferences.

## Resolved Inputs

- maintainer decisions: Add network status to the panel; show actual receive/upload activity rather than online/offline reachability.
- repo-researched facts: Network provider, presentation, history, detail rows, and preferences primitives already exist; the PRD names Network as an initial compact status metric.
- assumptions: Aggregated non-loopback interface byte counters are sufficient for the MVP.

## Goals

- Show Network in the panel by default.
- Show current receive and upload throughput.
- Show receive and upload as separate graph traces in the compact row.
- Keep Network ordered with the other compact status modules.
- Let users disable or reorder Network through existing status module preferences.
- Ensure provider refresh requirements include Network when it is visible.

## Non-goals

- Build per-interface analytics.
- Add Network to the menu bar glance supported set.
- Redesign the status section layout.

## User Stories

- As a user, I want to see receive and upload activity in the panel so I can quickly notice active transfers.
- As a user, I want Network to behave like other panel status modules so I can hide or reorder it if I do not need it.

## UX Requirements

### Entry Point

The Network row appears in the existing panel status section. Preferences expose Network in the existing status modules list.

### Layout

Network uses the same full-width status metric row pattern as CPU, Memory, and Storage. The value shows receive rate, the subtitle shows upload rate, and the sparkline draws receive and upload as separate traces while staying within the existing compact row footprint. Receive uses the same blue cue in the value and graph trace; upload uses the same orange cue in the subtitle and graph trace.

### States

- loading: Takes a short initial second sample and shows `Sampling` only when two valid counter samples are not available.
- empty: Not applicable; the status section is omitted only when all status modules are disabled.
- unavailable: Show the provider's unavailable state and normal detail popover behavior.
- permission required: No new permission state.
- success: Show receive/upload rates and throughput detail rows.
- failure: Provider failure remains represented as unavailable.

## Functional Requirements

1. Network must be part of the default panel status module order.
2. Network must be enabled by default for panel status modules.
3. Network must be included in normalized status module order for existing preferences that predate the Network panel row.
4. Existing enabled-module preferences that predate the Network panel row must enable Network once by default, without re-enabling it after the user later disables Network.
5. Network must compute receive/upload throughput from sequential local interface counter samples.
6. Network must take a short initial second sample so the panel can show throughput without waiting for the next scheduled refresh.
7. Network must show a sampling state when two valid counter samples are not available.
8. Network must keep separate receive and upload history for the compact row graph.
9. Network must be persisted when the user enables, disables, or reorders status modules.
10. When visible, Network must be included in `statusModulesRequiredForRefresh`.

## Behavior Scenarios

### Main Path

Given default settings
When the panel opens
Then the status section shows CPU, Memory, Storage, and Network in order.

Given Network has at least two samples
When the panel refreshes
Then the Network row shows current receive and upload rates and graphs both directions as separate traces.

### Relevant Edge States

Given a user disables Network in preferences
When the panel opens
Then the status section omits Network and provider refresh is not required for panel visibility alone.

Given older stored status module order omits Network
When settings load
Then Network is appended to the normalized status module order and remains configurable.

Given older stored enabled status modules omit Network because the module did not exist yet
When settings load
Then Network is enabled once by default and the migration is marked complete.

## Acceptance Criteria

- Default settings include Network in `statusModuleOrder`, `enabledStatusModules`, and `visiblePanelStatusModules`.
- Network can be disabled and persists in `enabledStatusModules`.
- Existing normalized orders append Network without losing stored CPU, Memory, or Storage order.
- Existing enabled-module preferences migrate Network on once and then preserve explicit user disablement.
- Network sparkline renders receive and upload as separate series.
- Network provider tests cover sampling, receive/upload throughput, idle traffic, counter reset, unavailable state, and formatting.
- System status store tests cover previous-sample caching for Network.
- Focused settings and panel store tests pass.

## Metrics

- perceived latency: no new visible wait beyond existing status refresh.
- reliability: sampling and unavailable states render without crashing.
- resource use: network reader is only required when Network is enabled in panel or another supported consumer requires it.

## Rollout

- MVP: Add Network to default panel status modules, show receive/upload throughput, and update tests.
- later: Decide whether Network should support menu bar glance display.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/runs/configurable-status-modules`
