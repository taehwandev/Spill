# Detailed PRD: Panel Accessibility Smoke

## PRD Authoring Gate

Do not author this PRD until `00-intake.md` has `Decision: build` and all clarifying questions are resolved. If intent, scope, value, UI behavior, feasibility, permissions, or distribution impact is unclear, return to `00-intake.md`, ask the maintainer, and stop here.

## Summary

Panel Accessibility Smoke extends the existing panel layout smoke test with a
small accessibility-tree check. The app should open the panel in smoke mode,
collect required panel accessibility labels from its own UI, log diagnostics,
and fail the smoke script when required landmarks are missing.

## Resolved Inputs

- maintainer decisions: continue the repository work.
- repo-researched facts: `scripts/verify-panel-layout-smoke.sh` already builds
  the app, opens the panel in smoke mode, and fails on layout/content diagnostic
  failures.
- assumptions: checking missing key labels satisfies M1-T4 for this slice; pixel
  diffing remains out of scope.

## Goals

- Detect missing key panel labels in automated smoke verification.
- Keep the check independent of Accessibility permission prompts.
- Preserve existing layout and content smoke behavior.

## Non-goals

- Change panel visual design.
- Add screenshot baselines.
- Verify third-party app accessibility trees.

## User Stories

- As a contributor, I want panel smoke verification to fail when important
  labels disappear so regressions are caught before release.

## UX Requirements

### Entry Point

The check runs through `python3 .agents/scripts/workflow.py panel-layout-smoke`
and `scripts/verify-panel-layout-smoke.sh`.

### Layout

No layout changes. Existing panel labels such as Spill, STATUS, AI, and
Sleep Guard must remain discoverable when the panel is opened by smoke mode.

### States

- loading: the smoke script waits for the panel to open and report diagnostics.
- empty: required labels still exist even when no detected menu bar items are
  available.
- unavailable: unavailable provider values are acceptable if labels are present.
- permission required: the panel may show permission-required state without
  prompting during smoke mode.
- success: logs include panel accessibility diagnostics and an OK marker.
- failure: logs include the missing required labels and the script exits nonzero.

## Functional Requirements

1. The panel controller exposes a smoke-only accessibility report for the
   current panel.
2. The report records required labels, discovered labels, and a pass/fail state.
3. The smoke app logs `SPILL_PANEL_ACCESSIBILITY ...` and either
   `SPILL_PANEL_ACCESSIBILITY_OK` or `SPILL_PANEL_ACCESSIBILITY_FAIL`.
4. The panel layout smoke script fails when the accessibility report is missing
   or failed.
5. The check does not request Accessibility permission and does not inspect
   other apps.

## Behavior Scenarios

### Main Path

Given Spill is launched in panel layout smoke mode
When the panel opens
Then the app logs panel layout, content, and accessibility diagnostics.

### Relevant Edge States

Given a required panel label is absent from the accessibility report
When the smoke script reads the app log
Then the script prints the log and exits with failure.

## Acceptance Criteria

- Smoke verification can detect missing required panel labels.
- The existing panel layout smoke command remains the single entry point.
- The check passes without Accessibility permission.
- Unit tests cover report pass and failure behavior.

## Metrics

- perceived latency: no end-user impact; smoke traversal runs after the panel is
  visible.
- reliability: deterministic labels should not depend on live provider data.
- resource use: one bounded tree traversal in smoke mode.

## Rollout

- MVP: label-based accessibility smoke diagnostics.
- later: screenshot or pixel-level visual baselines if needed.

## References

- `.agents/tasks/roadmap.yml` M1-T4.
- `scripts/verify-panel-layout-smoke.sh`.
