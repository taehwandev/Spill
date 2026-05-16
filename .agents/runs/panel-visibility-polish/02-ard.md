# Detailed ARD: Panel Visibility Polish

## Architecture Summary

Keep the existing provider architecture and improve presentation only. Providers
continue to own status values. Panel views render richer inline summaries, and
the menu bar renderer switches from dot chips to icon chips.

## Decisions

### D1: Presentation Polish Only

Decision: Do not add new metric providers in this slice.

Rationale: The complaint includes accuracy concerns, but the immediate issue is
that existing metric definitions and controls are poorly exposed.

Alternatives considered: adding storage, memory pressure, temperature, and
throughput providers now was rejected because that expands scope beyond the
current UI fix.

### D2: One-Decimal Defaults

Decision: Make tenths the default precision for menu bar and provider percent
text.

Rationale: One decimal place makes the UI feel intentional and allows easier
comparison with other monitoring tools.

Alternatives considered: keeping whole percentages was rejected because it was a
specific maintainer complaint.

### D3: Wider Compact Panel

Decision: Increase the panel width and verified height limit while keeping the
surface tray-sized.

Rationale: The current 320px layout clips useful labels. A modest wider panel
fits the existing control tray better than hiding values.

Alternatives considered: a large dashboard was rejected by PRD/ARD direction.

## Modules Affected

- `Sources/Spill/MenuBar/`
- `Sources/Spill/Panel/`
- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Sources/Spill/Providers/SystemMemoryProvider.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Tests/SpillTests/`

## New Types / APIs

No durable new model types are required.

## Data Flow

```text
system provider -> status store -> menu bar summary / panel status card -> user
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: not used.
- Network: unchanged.
- File system: unchanged.

## Failure Modes

- True CPU reader failures can still show unavailable in detail rows.
- Initial CPU sampling no longer creates a gray `--` in the menu bar.
- Wider panel can still be clamped to screen edges by existing layout.

## Performance Notes

CPU sampling may use a slightly longer interval for less jitter, but it remains
inside the existing async refresh path.

## Test Strategy

### Automated

- `swift test`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`
- `python3 .agents/scripts/workflow.py verify`

### Manual

- Confirm menu bar chips show icons and one-decimal values.
- Confirm Settings and Quit are visible in the panel header.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| T1 | Builder | menu bar chips, precision, CPU/memory formatting | No |
| T2 | Builder | panel width, status cards, header controls | No |
| T3 | Verifier | tests and smoke docs | No |

## Risks

- Metric values will still differ from other tools when those tools use
  different sample windows or memory definitions.
