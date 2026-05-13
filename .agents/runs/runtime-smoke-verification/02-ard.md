# ARD: Runtime Smoke Verification

## Architecture Summary

Add an environment-driven smoke mode to `AppDelegate` and a shell script that builds and launches the bundled app. The app prints readiness markers and exits automatically only when `SPILL_SMOKE_TEST=1` is set.

## Decisions

### D1: Environment-Driven Smoke Mode

Decision:

Use `SPILL_SMOKE_TEST=1` to activate non-interactive startup behavior.

Rationale:

This avoids adding user-facing preferences or command-line parsing to the normal app. Environment variables are simple for scripts and CI.

Alternatives considered:

- Separate smoke executable: rejected as more maintenance.
- UI automation only: rejected because it still needs a reliable app startup signal.

### D2: Keep Runtime Smoke Out Of Default Verify

Decision:

Expose `runtime-smoke` as a separate workflow command instead of running it inside default `verify`.

Rationale:

Default verification should stay deterministic and non-GUI. Runtime smoke launches a macOS app and may not be appropriate for every environment.

## Modules Affected

- `Sources/Spill/App/AppDelegate.swift`
- `scripts/verify-runtime-smoke.sh`
- `.agents/scripts/workflow.py`
- README and agent workflow docs

## New Types / APIs

None.

## Data Flow

```text
workflow command -> smoke script -> build app -> launch app with env -> readiness log -> clean exit
```

## Permissions

- Accessibility: not requested in smoke mode.
- Screen Recording: not used.
- Network: not used.
- File system: writes a temporary smoke log.

## Failure Modes

- Build fails.
- App exits non-zero.
- App does not print readiness marker.
- App does not exit before timeout.

## Performance Notes

The script timeout is short and cleans up the app process on failure.

## Test Strategy

### Automated

- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py language-gates`

### Manual

- Confirm normal app launch still opens Preferences outside smoke mode.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Add smoke mode and script | Builder | `AppDelegate.swift`, `scripts/verify-runtime-smoke.sh`, workflow docs | No |
| Verify runtime command | Verifier | workflow output | After builder |

## Risks

- Smoke mode validates process readiness but not visible menu bar pixels.
- Shell script behavior is macOS-specific.
