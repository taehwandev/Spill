# PRD: Menu Bar Glance Summary

## Summary

Keep the macOS menu bar glance summary short by limiting the default clock-area status surface to CPU and memory percentage chips. AI, GPU, network, Sleep Guard, and window actions remain available in the panel, where there is enough room for labels and detail.

## Goals

- Show CPU and memory as compact visual percentage chips in the existing single `NSStatusItem`.
- Keep CPU and memory visible and detailed in the panel.
- Prevent stale settings or panel toggles from reintroducing AI, GPU, or network into the menu bar summary for this slice.
- Preserve icon-only behavior when all menu bar glance values are disabled.

## Non-goals

- No AI active detection in the menu bar.
- No GPU or network menu bar glance value.
- No second status item.
- No private menu bar placement API.
- No new formatting preferences in this slice.

## User Stories

- As a user, I can glance near the system clock and see only CPU and memory load.
- As a user, I can open the panel to inspect AI, GPU, network, and detailed system readings.
- As a user with a crowded menu bar, I am not forced to carry long GPU, AI, or network labels.

## UX Requirements

### Entry Point

The existing Spill status item shows compact CPU and memory chips when those menu bar values are enabled. Clicking it opens the same Spill panel.

### Layout

The menu bar summary uses small AppKit chips with an SF Symbol, monospaced percentage value, and a narrow usage bar. The panel keeps richer two-line status cells and popover details.

### States

- loading: existing cached values remain until the next refresh.
- empty: icon-only status item when CPU and memory menu bar values are disabled.
- unavailable: unavailable values render as `--`.
- permission required: unchanged panel permission state.
- success: CPU and memory chips render in default order.
- failure: provider failures fall back to unavailable values.

## Functional Requirements

1. Default enabled menu bar status items must be CPU and memory only.
2. Menu bar summary generation must ignore AI, GPU, and network even if old persisted settings contain them.
3. Panel detail popovers must offer `Show in menu bar` only for CPU and memory.
4. AI, GPU, and network must remain visible in the panel when their panel modules are enabled.
5. The implementation must keep a single `NSStatusItem`.
6. Enabled menu bar values must render as visual chips rather than plain attributed title text.

## Acceptance Criteria

- Default menu bar summary is CPU and memory only.
- CPU and memory use percentage values inside visual chips.
- AI, GPU, and network are not shown in the menu bar by default or by stale persisted values.
- `swift test` and workflow gates pass.

## Metrics

- perceived latency: unchanged from existing refresh loop.
- reliability: stale persisted unsupported values are ignored.
- resource use: no new polling source.

## Rollout

- MVP: CPU and memory percentages only.
- later: formatting preferences and verified AI active detection can be reconsidered in separate slices.

## References

- `.agents/workflows/implementation.md`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
