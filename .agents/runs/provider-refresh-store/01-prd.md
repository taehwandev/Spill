# Detailed PRD: Provider Refresh Store

## Summary

Add an observable system status store that owns the current memory and power snapshots for the Spill panel. The store refreshes provider values explicitly and exposes cached values to SwiftUI, avoiding direct provider reads during view rendering.

## Goals

- Move memory and power reads out of `SpillBarView` computed properties.
- Provide default initial statuses that render safely before refresh.
- Add deterministic tests for refresh behavior.
- Preserve the current panel layout and visible behavior.

## Non-goals

- No new provider types.
- No background polling outside the panel lifecycle.
- No user settings.
- No visual redesign.

## User Stories

- As a user, I want the panel to remain responsive as more status providers are added.
- As a contributor, I want one obvious place to add provider refresh behavior.
- As a maintainer, I want tests that confirm the panel can consume cached provider state.

## UX Requirements

### Entry Point

The existing panel is the entry point. There is no new user-facing control.

### Layout

The panel continues to show the existing `MEMORY` meter and compact power footer value.

### States

- loading: initial store state may use unavailable/default statuses until refresh.
- empty: not applicable.
- unavailable: provider-specific unavailable state is preserved.
- permission required: not applicable.
- success: refreshed provider values populate the panel.
- failure: failed reads keep unavailable provider state.

## Functional Requirements

1. Add an observable store for system provider state.
2. Store current `SystemMemoryStatus` and `SystemPowerStatus`.
3. Refresh both values through injectable closures for testability.
4. Instantiate the store in the panel controller and pass it into `SpillBarView`.
5. Refresh the store when the panel is shown and when the SwiftUI view appears.
6. Add unit tests for initial state and refresh injection.

## Acceptance Criteria

- `SpillBarView` does not call `SystemMemoryProvider.status()` or `SystemPowerProvider.status()` directly.
- Existing memory and power UI remains visible.
- `swift build` passes.
- `swift test` passes.
- Workflow gates pass.

## Metrics

- perceived latency: no visible delay when opening the panel.
- reliability: unavailable provider states are safe defaults.
- resource use: no polling loop is introduced in this slice.

## Rollout

- MVP: store with explicit refresh on panel show and view appear.
- later: provider registry, timer-based visible refresh, async fan-out, error telemetry.

## References

- `.agents/tasks/roadmap.yml`
- `Sources/Spill/Providers/SystemMemoryProvider.swift`
- `Sources/Spill/Providers/SystemPowerProvider.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
