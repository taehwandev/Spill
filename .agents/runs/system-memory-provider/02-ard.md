# Detailed ARD: System Memory Provider

## Architecture Summary

The feature adds a small system provider in `Sources/Spill/Providers`. The provider reads memory statistics through Mach host APIs, converts the reading into `SystemMemoryStatus`, exposes a `SpillStatusItem`, and lets `SpillBarView` render a `MEMORY` meter from that status. No provider registry is introduced in this slice.

## Decisions

### D1: Memory First, CPU and Battery Later

Decision:

Implement only memory usage in this slice.

Rationale:

Memory can be read as a point-in-time value without sampling loops or additional frameworks. CPU usage needs interval sampling and battery status needs power source handling, so both should be separate scoped features.

Alternatives considered:

- Add CPU and battery at the same time. Rejected to avoid fake values and broad system-provider complexity.
- Keep only `ACCESS` and `ACTIONS`. Rejected because the panel needs a real system status signal.

### D2: Use Mach Host Statistics

Decision:

Use public Darwin Mach host statistics to read VM page counts.

Rationale:

The API is local, fast, and does not require new permissions. It is appropriate for a native macOS utility distributed outside private API boundaries.

Alternatives considered:

- Shell out to `vm_stat`. Rejected because parsing command output is less robust.
- Use private frameworks. Rejected by project policy.

### D3: Keep Provider Mapping Pure and Testable

Decision:

Separate raw memory reading from mapping into `SystemMemoryStatus` and `SpillStatusItem`.

Rationale:

Tests can cover calculation and state thresholds without relying on host-specific memory values.

Alternatives considered:

- Render Mach values directly in SwiftUI. Rejected because it would couple UI to system API details.

## Modules Affected

- `Sources/Spill/Providers/SystemMemoryProvider.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Tests/SpillTests/SystemMemoryProviderTests.swift`
- `.agents/runs/system-memory-provider/`
- `.agents/design/stitch.md`

## New Types / APIs

- `SystemMemoryReading`
- `SystemMemoryStatus`
- `SystemMemoryProvider.status()`
- `SystemMemoryProvider.status(from:)`
- `SystemMemoryProvider.snapshot()`

## Data Flow

```text
Mach host statistics
  -> SystemMemoryReading
  -> SystemMemoryStatus
  -> SpillStatusItem
  -> SpillBarView MEMORY meter
```

## Permissions

- Accessibility: not used.
- Screen Recording: not used.
- Network: not used.
- File system: not used.

## Failure Modes

- Mach statistics fail: memory status becomes unavailable with `N/A`.
- Total memory is zero: memory status becomes unavailable.
- Used memory exceeds total due to accounting variance: ratio is clamped to 1.

## Performance Notes

- Memory is read synchronously and only when the panel view computes status.
- No polling, timers, background tasks, or sampling windows are introduced.

## Test Strategy

### Automated

- Unit tests for usage ratio, formatting, state thresholds, unavailable fallback, and status item mapping.
- `swift build`
- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py panel-open-smoke`
- `git diff --check`

### Manual

- Open the panel and confirm `MEMORY` appears in the status section.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Run documentation | Product | `.agents/runs/system-memory-provider/` | Yes |
| Memory provider | Builder | `Sources/Spill/Providers/SystemMemoryProvider.swift` | Yes |
| Panel integration | Builder | `Sources/Spill/Panel/SpillBarView.swift`, `.agents/design/stitch.md` | After provider API is stable |
| Tests and verification | Verifier | `Tests/SpillTests/SystemMemoryProviderTests.swift`, run closeout docs | After provider implementation |

## Risks

- Memory accounting differs from Activity Monitor because this uses a compact provider calculation.
- Without a refresh cadence, memory updates when the panel view recomputes rather than continuously.
