# Detailed PRD: System CPU Provider

## PRD Authoring Gate

Do not author this PRD until `00-intake.md` has `Decision: build` and all clarifying questions are resolved. If intent, scope, value, UI behavior, feasibility, permissions, or distribution impact is unclear, return to `00-intake.md`, ask the maintainer, and stop here.

## Summary

Add a CPU status provider foundation that calculates CPU utilization from two public Mach CPU tick readings. The provider should expose a `SpillStatusItem`, deterministic status mapping, and unit tests. This run does not add visible CPU UI.

## Goals

- Add `SystemCPUReading`, `SystemCPUStatus`, and `SystemCPUProvider`.
- Calculate CPU usage from previous/current CPU tick deltas.
- Provide unavailable fallback for missing or invalid samples.
- Add tests for normal, active, warning, unavailable, zero-delta, and status-item mapping.

## Non-goals

- No visible panel integration.
- No polling loop.
- No process-level CPU list.
- No CPU history chart.

## User Stories

- As a maintainer, I want CPU usage represented as a plain provider model before placing it in the panel.
- As a contributor, I want CPU mapping tests so UI work can rely on stable behavior.
- As a future user, I want CPU state to be compact and low-overhead.

## UX Requirements

### Entry Point

No user-facing entry point in this slice.

### Layout

Nothing new appears in the panel yet.

### States

- loading: not applicable.
- empty: not applicable.
- unavailable: provider returns `N/A` when readings are missing or invalid.
- permission required: not applicable.
- success: provider maps sampled tick deltas into percentage and state.
- failure: same visual model as unavailable.

## Functional Requirements

1. Read aggregate CPU tick counters through public Mach APIs.
2. Convert two readings into a usage ratio.
3. Treat user, system, and nice ticks as active CPU time.
4. Treat idle ticks as inactive CPU time.
5. Return unavailable when samples are missing, reversed, or have no delta.
6. Produce a `SpillStatusItem` with stable provider metadata.

## Acceptance Criteria

- `swift build` passes.
- `swift test` passes.
- CPU provider tests pass.
- No `SpillBarView` changes are made.
- No new permissions are introduced.

## Metrics

- perceived latency: no visible UI impact in this slice.
- reliability: invalid samples map to unavailable rather than crashing.
- resource use: no polling loop is introduced.

## Rollout

- MVP: tested provider foundation only.
- later: integrate into `SystemStatusStore` and panel after UI placement is approved.

## References

- `Sources/Spill/Providers/SystemMemoryProvider.swift`
- `Sources/Spill/Providers/SpillStatusModels.swift`
- `.agents/tasks/roadmap.yml`
