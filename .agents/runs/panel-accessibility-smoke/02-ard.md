# Detailed ARD: Panel Accessibility Smoke

## Architecture Summary

Add a smoke-only accessibility report beside the existing panel layout and
content reports. The report should inspect Spill's own panel accessibility tree,
normalize visible labels, compare them against a small required label set, and
emit diagnostics through the existing smoke-mode logging path.

## Decisions

### D1: Keep The Check Inside Panel Smoke Mode

Decision: Run accessibility diagnostics only when the panel layout smoke
environment is enabled.

Rationale: This keeps production behavior unchanged and reuses the existing
build/open/wait/fail script path.

Alternatives considered: a separate app automation test was rejected because it
would add another launch path and may need external Accessibility permission.

### D2: Validate Required Labels Instead Of Pixel Baselines

Decision: Treat missing key labels as the automated regression signal for this
slice.

Rationale: The roadmap allows detecting text overlap or missing key labels.
Label checks are deterministic in headless smoke contexts, while screenshot
baselines are more sensitive to macOS rendering differences.

Alternatives considered: pixel screenshots were deferred until the project needs
visual baseline storage and image comparison.

## Modules Affected

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillFooterView.swift`
- `Sources/Spill/Panel/SpillPanelAccessibilityReport.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `scripts/verify-panel-layout-smoke.sh`
- `Tests/SpillTests/SpillPanelAccessibilityReportTests.swift`

## New Types / APIs

```swift
struct SpillPanelAccessibilityReport {
    let requiredLabels: [String]
    let discoveredLabels: [String]
    var isValid: Bool { get }
    var logLine: String { get }
}
```

## Data Flow

```text
panel content view -> accessibility tree traversal -> report -> smoke log -> shell script gate
```

## Permissions

- Accessibility: no external Accessibility permission required; the app inspects
  its own panel view tree.
- Screen Recording: not used.
- Network: not used.
- File system: only existing smoke log writes through the shell script.

## Failure Modes

- SwiftUI may expose fewer accessibility elements than expected; required
  labels should be attached explicitly to stable panel landmarks.
- A missing panel or empty tree should fail the report with clear diagnostics.
- Pixel overlap can still escape this label-only slice.

## Performance Notes

- The traversal runs only in smoke mode after panel presentation.
- Required label matching is case-insensitive and uses normalized whitespace.

## Test Strategy

### Automated

- Unit tests for report success and missing-label failure.
- `swift test`.
- `python3 .agents/scripts/workflow.py panel-layout-smoke`.

### Manual

- Manual panel inspection remains useful for true visual overlap and rendering
  quality.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| T1 | Builder | panel report, AppDelegate smoke logging, script gate | No |
| T2 | Verifier | tests and run documentation | No |

## Risks

- Accessibility labels can change when SwiftUI rendering changes; keep required
  labels focused on stable landmarks.
