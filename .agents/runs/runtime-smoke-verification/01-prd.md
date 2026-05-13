# PRD: Runtime Smoke Verification

## Summary

Add a smoke mode and verification script for bundled app startup. The script should build `.build/Spill.app`, launch Spill with smoke environment variables, confirm readiness output, and verify clean shutdown.

## Goals

- Verify the app bundle can launch.
- Verify app startup reaches the point where the status item controller is initialized.
- Avoid Preferences windows and Accessibility prompts during automated smoke runs.
- Make the check available through the agent workflow command surface.

## Non-goals

- No pixel-level menu bar verification.
- No UI automation.
- No Screen Recording or Accessibility permission automation.
- No normal user-facing behavior changes.

## User Stories

- As a maintainer, I can run one command to verify the bundled app starts and exits.
- As a verifier agent, I can include runtime smoke output in verification notes.
- As a contributor, I can catch lifecycle regressions before manual testing.

## UX Requirements

### Entry Point

`python3 .agents/scripts/workflow.py runtime-smoke`

### States

- success: script prints that runtime smoke passed.
- failure: script prints the app log and exits non-zero.
- timeout: script kills the app process and exits non-zero.

## Functional Requirements

1. Add `SPILL_SMOKE_TEST` mode.
2. Smoke mode must suppress startup Preferences and Accessibility permission prompts.
3. Smoke mode must print readiness and shutdown markers.
4. The verification script must build the app bundle before launching it.
5. The workflow helper must expose a runtime smoke command.

## Acceptance Criteria

- `python3 .agents/scripts/workflow.py runtime-smoke` passes locally.
- `python3 .agents/scripts/workflow.py verify` still passes.
- Normal app startup behavior remains unchanged when `SPILL_SMOKE_TEST` is not set.

## Metrics

- perceived latency: smoke should complete in under 10 seconds after build.
- reliability: process timeout and non-zero exit are reported clearly.
- resource use: no long-running app process remains after the script exits.

## Rollout

- MVP: local smoke script and workflow command.
- later: add CI integration for macOS runners.

## References

- `.agents/workflows/implementation.md`
- `.agents/checklists/review.md`
