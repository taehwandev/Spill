# Detailed ARD: Panel Content UI Polish

## Architecture Summary

This pass changes SwiftUI composition and sizing only. Existing providers, settings state, refresh loops, Accessibility scanner, and action executors remain the source of data and behavior.

## Decisions

### D1: Preserve Provider Boundaries

Decision:

Keep all system, AI, window, and menu bar data reads in existing stores and providers.

Rationale:

The request is a UI hierarchy polish pass, not a data model change.

Alternatives considered:

- Adding new provider outputs for visual layout. Rejected because existing status and action models are sufficient.

### D2: Content-Based Stitch Mapping

Decision:

Use only the Stitch panel content structure: header, performance stack, active action row, and quick status pill. Ignore the left settings/navigation mock.

Rationale:

The maintainer explicitly marked the left UI as not meaningful for this implementation pass.

Alternatives considered:

- Recreating the full Stitch desktop scene. Rejected because it conflicts with compact tray direction.

### D3: Compact Native Controls

Decision:

Use native SwiftUI controls, existing SF Symbols, and restrained glass styling. Keep cards at 8px radius or lower for repeated items and avoid nested cards.

Rationale:

This matches current code patterns and frontend guidance for compact operational tools.

Alternatives considered:

- A large dashboard layout. Rejected by PRD and ARD.

## Modules Affected

- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillFooterView.swift`
- `Sources/Spill/Panel/SpillActionViews.swift`
- `Sources/Spill/Panel/SpillPanelMetrics.swift`
- panel smoke scripts/tests only if existing checks need label updates

## New Types / APIs

No public APIs are added. Any helper views remain private to panel files.

## Data Flow

```text
existing providers/stores -> existing panel view models -> SwiftUI section polish -> user action
```

## Permissions

- Accessibility: unchanged
- Screen Recording: unchanged, not used
- Network: unchanged, not used
- File system: unchanged

## Failure Modes

- Overly dense rows could reduce readability.
- Changed accessibility labels could require smoke check updates.
- Panel could exceed compact layout bounds if spacing grows.

## Performance Notes

View-only changes must not add timers, polling, scanner refreshes, or network calls.

## Test Strategy

### Automated

- `swift test`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`
- `python3 .agents/scripts/workflow.py verify`
- `git diff --check`

### Manual

- Relaunch the app.
- Open and close the panel.
- Confirm no visible overlap.
- Confirm Settings, Quit, Sleep Guard, status rows, AI, window actions, and menu bar actions are visible.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Document content-based Stitch mapping | builder | `.agents/runs/panel-content-ui-polish/*` | no |
| Polish panel hierarchy | builder | `SpillBarView.swift`, `SpillActionViews.swift`, `SpillFooterView.swift` | no |
| Verify and update docs | builder | run verification docs | no |

## Risks

- Manual screenshot iteration may still be needed after this pass because automated smoke checks cannot fully judge visual polish.
