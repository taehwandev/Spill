# Detailed ARD: Panel Open Smoke

## Architecture Summary

The existing smoke mode remains the base launch path. `AppDelegate` reads an additional `SPILL_SMOKE_OPEN_PANEL` environment variable and, when set, opens the panel through the same `SpillPanelController` used by normal UI paths. The script validates explicit log markers instead of relying on screen capture.

## Decisions

### D1: Use Log Markers Instead of Screenshots

Decision:

Verify panel presentation by checking `SpillPanelController.isVisible` and printing `SPILL_PANEL_SMOKE_VISIBLE`.

Rationale:

Screen capture can fail in restricted sessions and requires additional permission. A log marker is stable and exercises the presentation path.

Alternatives considered:

- Use `screencapture` for a screenshot. Deferred because screen capture is not consistently available.
- Add test-only fake SwiftUI rendering. Rejected because it does not exercise the AppKit panel controller.

### D2: Avoid Accessibility Prompt During Panel Smoke

Decision:

Panel smoke opens the panel without calling `AccessibilityPermission.request()`.

Rationale:

Smoke tests must be noninteractive. The panel can render permission-required state without needing Accessibility trust.

Alternatives considered:

- Use the normal `showSpillBar()` path. Rejected because it may request Accessibility and block automation.

### D3: Keep Runtime Smoke Backward Compatible

Decision:

Existing `runtime-smoke` remains unchanged and a new `panel-open-smoke` command is added.

Rationale:

Separating startup smoke from panel smoke keeps failures easier to diagnose.

Alternatives considered:

- Always open the panel in runtime smoke. Rejected because startup smoke should stay minimal.

## Modules Affected

- `Sources/Spill/App/AppDelegate.swift`
- `scripts/verify-panel-open-smoke.sh`
- `.agents/scripts/workflow.py`
- `.agents/runs/panel-open-smoke/`

## New Types / APIs

- `SPILL_SMOKE_OPEN_PANEL=1`
- `SPILL_PANEL_SMOKE_VISIBLE` log marker
- `SPILL_PANEL_SMOKE_NOT_VISIBLE` log marker
- `python3 .agents/scripts/workflow.py panel-open-smoke`

## Data Flow

```text
verify-panel-open-smoke.sh
  -> build-app.sh
  -> SPILL_SMOKE_TEST=1 SPILL_SMOKE_OPEN_PANEL=1 Spill
  -> AppDelegate opens SpillPanelController
  -> log marker
  -> script validates marker and exit status
```

## Permissions

- Accessibility: not requested in panel smoke.
- Screen Recording: not used.
- Network: not used.
- File system: script writes a temporary log file only.

## Failure Modes

- App exits non-zero: script fails and prints log.
- Panel visible marker missing: script fails and prints log.
- Panel controller reports not visible: app prints failure marker and script fails.
- Timeout: script kills the process and prints log.

## Performance Notes

- Uses existing release app build path.
- Smoke exit delay remains configurable.
- No new production timers are added.

## Test Strategy

### Automated

- `swift build`
- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py panel-open-smoke`
- `git diff --check`

### Manual

- Optional launch and visual panel inspection.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Run documentation | Product | `.agents/runs/panel-open-smoke/` | Yes |
| App smoke mode | Builder | `Sources/Spill/App/AppDelegate.swift` | Yes |
| Script and workflow command | Builder | `scripts/verify-panel-open-smoke.sh`, `.agents/scripts/workflow.py` | Yes |
| Verification | Verifier | run closeout docs | After implementation |

## Risks

- A visible marker confirms panel controller state, not pixel-perfect rendering.
- Some macOS sessions may still display no visible window even if AppKit marks the panel visible; screenshot verification is a later layer.
