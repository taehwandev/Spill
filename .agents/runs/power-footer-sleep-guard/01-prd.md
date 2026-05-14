# Detailed PRD: Power Footer And Sleep Guard

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, and the maintainer clarified the central product rule: Sleep Guard is off by default and only activates after a time duration is selected.

## Summary

Add two power-related improvements. First, let users hide the compact power footer status when it duplicates macOS battery state. Second, add a time-based Sleep Guard control that prevents idle system sleep for a selected duration and then automatically turns off.

## Goals

- Add a user setting for the power footer status.
- Add a dedicated Sleep Guard footer control.
- Keep Sleep Guard off by default.
- Activate Sleep Guard only after selecting a duration.
- Automatically turn Sleep Guard off when time expires.
- Release assertions when the user stops Sleep Guard or the app exits.
- Use only public macOS APIs.

## Non-goals

- No indefinite mode.
- No custom duration editor.
- No `pmset` mutation.
- No second macOS menu bar item.
- No dashboard-sized power view.

## User Stories

- As a user, I want to hide Spill's power footer when macOS battery status is enough.
- As a user, I want to keep my Mac awake for a short task without opening a separate app.
- As a user, I want to see when Sleep Guard is active and how much time remains.

## UX Requirements

### Entry Point

The panel footer shows a Sleep Guard control. Preferences shows power and Sleep Guard options.

### Layout

The footer keeps the existing compact capsule. Sleep Guard appears as an icon and only shows a time label while active. The power footer item is shown only when the setting is enabled.

### States

- loading: Sleep Guard remains off until a user action.
- empty: not applicable.
- unavailable: failed assertion creation shows an error tooltip and returns to off.
- permission required: no new permission requirement.
- success: active state shows remaining time.
- failure: failed assertion creation releases any partial assertion and remains off.

## Functional Requirements

1. Persist `showPowerFooter`.
2. Persist `sleepGuardKeepsDisplayAwake`.
3. Add a Sleep Guard controller with inactive default state.
4. Support fixed durations: 15 minutes, 30 minutes, 1 hour, and 2 hours.
5. Create a user idle system sleep assertion only when a duration is selected.
6. Optionally create a user idle display sleep assertion when the preference is enabled.
7. Release all assertions on stop, expiry, or application termination.
8. Skip power provider reads when the power footer is hidden.
9. Keep panel UI compact and avoid adding any extra status item.

## Acceptance Criteria

- The power footer can be hidden by setting.
- Hidden power footer state does not run the power reader.
- Sleep Guard is off at launch.
- Selecting a duration creates an assertion.
- Stopping Sleep Guard releases the assertion.
- Expiry releases the assertion.
- Tests verify assertion creation and release with a fake manager.
- `swift build`, `swift test`, workflow gates, and smoke checks pass.

## Metrics

- perceived latency: opening the duration menu must not block.
- reliability: assertions are released on stop and app termination.
- resource use: no timer or assertion runs while Sleep Guard is off.

## Rollout

- MVP: footer control with fixed durations and preferences.
- later: custom duration and richer detail state if users need it.

## References

- Apple IOKit power assertion APIs.
- `.agents/runs/system-power-provider`
- `.agents/runs/configurable-status-modules`
