# Detailed PRD: Panel Open Smoke

## Summary

Panel open smoke adds an opt-in runtime verification mode that opens the Spill panel during launch and logs whether the panel controller reports visible state. This supplements the existing app startup smoke and gives maintainers a deterministic way to exercise the panel presentation path.

## Goals

- Add an environment-gated panel-open smoke mode.
- Avoid Accessibility permission prompts during smoke.
- Add a script that builds the app, launches smoke mode, and checks log markers.
- Add a workflow command for panel-open smoke.
- Preserve existing runtime smoke behavior.

## Non-goals

- Do not add screenshot capture.
- Do not add visual diff testing.
- Do not add sample detected items.
- Do not change normal app launch behavior.
- Do not change status item behavior.

## User Stories

- As a maintainer, I want a command that proves the panel presentation path still works.
- As a contributor, I want a fast smoke command before changing panel code.
- As a user, I want fewer panel regressions in builds.

## UX Requirements

### Entry Point

No user-facing entry point. Developers run `python3 .agents/scripts/workflow.py panel-open-smoke` or `scripts/verify-panel-open-smoke.sh`.

### Layout

No new UI layout is introduced. The existing panel is shown in smoke mode.

### States

- loading: app prints `SPILL_SMOKE_READY`.
- success: app prints `SPILL_PANEL_SMOKE_VISIBLE`.
- failure: script fails if the marker is absent or the process exits non-zero.

## Functional Requirements

1. Add `SPILL_SMOKE_OPEN_PANEL=1` support in `AppDelegate`.
2. Panel smoke must call the existing panel controller.
3. Panel smoke must avoid Accessibility permission prompts.
4. Panel smoke must log a success marker only when the panel reports visible.
5. Add `scripts/verify-panel-open-smoke.sh`.
6. Add `panel-open-smoke` command to `.agents/scripts/workflow.py`.
7. Existing `runtime-smoke` must continue to pass.

## Acceptance Criteria

- `swift build` passes.
- `swift test` passes.
- `python3 .agents/scripts/workflow.py verify` passes.
- `python3 .agents/scripts/workflow.py runtime-smoke` passes.
- `python3 .agents/scripts/workflow.py panel-open-smoke` passes.
- No private API or status item spacer is introduced.

## Metrics

- reliability: panel-open smoke catches panel presentation failures.
- runtime: smoke completes under the existing timeout window.
- resource use: no new background work outside smoke mode.

## Rollout

- MVP: log-marker based panel-open smoke.
- later: optional screenshot artifact when screen capture permission is available.

## References

- `Sources/Spill/App/AppDelegate.swift`
- `scripts/verify-runtime-smoke.sh`
- `.agents/scripts/workflow.py`
