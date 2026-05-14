# Detailed PRD: System Memory Provider

## Summary

System Memory Provider adds a real memory usage status to Spill. It reads local memory statistics through public macOS APIs, maps them into provider status models, and renders the result in the compact panel status section. The feature avoids fake values and does not add background refresh.

## Goals

- Read current memory usage using public macOS APIs.
- Map memory usage into `SpillStatusItem`.
- Show a real `MEMORY` meter in the panel.
- Add focused tests for memory usage calculation and state thresholds.
- Keep the panel compact and avoid new permissions.

## Non-goals

- Do not add CPU usage.
- Do not add battery state.
- Do not add a provider registry.
- Do not add polling or live sampling.
- Do not change status item behavior.
- Do not add fake fallback metrics.

## User Stories

- As a user, I want the panel to show a real Mac status signal.
- As a maintainer, I want tests proving the memory provider does not fake values.
- As a contributor, I want a concrete provider example for future system status work.

## UX Requirements

### Entry Point

The existing panel shows memory status in its `STATUS` section. No new control is added.

### Layout

The `STATUS` section contains:

- `MEMORY`: current memory usage percentage and meter.
- `ACTIONS`: current visible action count and meter.

Accessibility readiness remains represented by the panel state and footer icon.

### States

- loading: no loading state; memory reads synchronously.
- empty: not applicable for memory.
- unavailable: show `N/A` and neutral meter if memory statistics cannot be read.
- permission required: not applicable; memory does not require Accessibility.
- success: show memory percentage and appropriate meter color.
- failure: unavailable state if Mach statistics fail.

## Functional Requirements

1. Add a memory status model with total, used, available, usage ratio, label, subtitle, and state.
2. Add a provider that can produce a `SpillStatusItem` for memory.
3. Use active, wired, and compressed memory as used memory.
4. Use free and inactive memory as available memory.
5. Clamp usage ratio to `0...1`.
6. Render memory in the panel status section.
7. Add unit tests for normal, elevated, high, unavailable, and formatting behavior.
8. Avoid timers, network calls, private APIs, and fake data.

## Acceptance Criteria

- `swift build` passes.
- `swift test` passes.
- Workflow gates pass.
- Runtime smoke passes.
- Panel-open smoke passes.
- Panel source shows `MEMORY` from the provider.
- No CPU, battery, or fake provider values are introduced.

## Metrics

- perceived latency: no visible delay when opening the panel.
- reliability: memory status gracefully falls back to unavailable state.
- resource use: one lightweight memory read per panel render.

## Rollout

- MVP: memory usage provider and panel row.
- later: provider registry, refresh cadence, CPU, battery, and AI status as separate features.

## References

- `Sources/Spill/Providers/SpillStatusModels.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Tests/SpillTests/SpillProviderModelsTests.swift`
