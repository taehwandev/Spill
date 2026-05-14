# Detailed ARD: System CPU Provider

## Architecture Summary

Add a provider-layer CPU model beside memory and power. The reader returns aggregate CPU tick counters from `host_statistics(HOST_CPU_LOAD_INFO)`. The pure mapper converts previous/current readings into a percentage, state, and `SpillStatusItem`.

## Decisions

### D1: Use aggregate Mach CPU load ticks

Decision: Use `host_statistics` with `HOST_CPU_LOAD_INFO`.

Rationale: It is a public macOS API, requires no permissions, and provides stable aggregate CPU counters. CPU percentage should be computed from deltas between two samples rather than from absolute tick values.

Alternatives considered: `top`, `ps`, and Activity Monitor parsing were rejected because they are command-output based and less structured. Per-core `host_processor_info` was deferred because the compact tray only needs aggregate CPU in this slice.

### D2: Provider only, no UI

Decision: Do not render CPU in the panel in this run.

Rationale: The next UI placement needs maintainer confirmation because adding another visible metric can affect compact layout.

Alternatives considered: Adding a third status meter was deferred.

## Modules Affected

- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Tests/SpillTests/SystemCPUProviderTests.swift`
- `.agents/tasks/roadmap.yml`

## New Types / APIs

```swift
struct SystemCPUReading {
    let userTicks: UInt64
    let systemTicks: UInt64
    let idleTicks: UInt64
    let niceTicks: UInt64
}

struct SystemCPUStatus {
    let value: String
    let subtitle: String?
    let usageRatio: Double
    let state: SpillStatusState
}

struct SystemCPUProvider: SpillStatusProvider {
    static func status(previous: SystemCPUReading?, current: SystemCPUReading?) -> SystemCPUStatus
}
```

## Data Flow

```text
Mach CPU ticks -> SystemCPUReading pair -> SystemCPUStatus -> SpillStatusItem
```

## Permissions

- Accessibility: not required.
- Screen Recording: not required.
- Network: not required.
- File system: not required.

## Failure Modes

- Missing sample: unavailable.
- Reversed or equal counters: unavailable.
- Zero total delta: unavailable.
- Usage above 100% due to malformed data: clamp to 100%.

## Performance Notes

- No polling loop is added.
- The async `snapshot()` path may take two short samples if used later.
- UI integration must avoid blocking rendering.

## Test Strategy

### Automated

- Unit tests for delta mapping and status item metadata.
- Existing workflow gates.

### Manual

- None required because this slice has no visible UI.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Provider | Builder | `Sources/Spill/Providers/SystemCPUProvider.swift`, `Tests/SpillTests/SystemCPUProviderTests.swift` | Yes |
| Docs | Verifier | `.agents/runs/system-cpu-provider/05-verification.md`, `.agents/runs/system-cpu-provider/06-closeout.md`, `.agents/tasks/roadmap.yml` | Yes after implementation |

## Risks

- A provider-only slice does not yet make CPU visible to users.
- CPU sampling semantics may differ from Activity Monitor.
