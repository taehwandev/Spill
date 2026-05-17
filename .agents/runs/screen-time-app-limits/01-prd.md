# Detailed PRD: Screen Time App Limits Compatibility

## PRD Authoring Gate

`00-intake.md` has `Decision: build` and `Clarity: clear`.

## Summary

Add Screen Time compatibility guidance so users understand and can resolve
macOS App Limit or Downtime shields that interfere with launching or clicking
Spill. Spill should not attempt to bypass Screen Time; it should point users to
the correct macOS settings and keep automated verification independent from
manual input.

## Resolved Inputs

- maintainer decisions: treat iTerm as an example, not the root cause.
- repo-researched facts: Spill's status item click route is verified by a
  dedicated smoke test.
- Apple docs: App Limits and Downtime can block apps; Always Allowed lets users
  allow specific apps during downtime or after time limits.
- assumptions: a settings shortcut and docs are the correct public-API product
  response.

## Goals

- Explain that Screen Time can block Spill or the launcher app.
- Provide a preferences button to open Screen Time settings.
- Document that Spill should be installed/launched as its own app and added to
  Always Allowed when Screen Time limits are used.
- Preserve the status-click smoke test as verification for Spill's own click
  route.

## Non-goals

- Override Screen Time.
- Modify App Limits or Always Allowed automatically.
- Add Screen Time API entitlements.
- Change panel UI or status item click semantics.

## User Stories

- As a user with App Limits enabled, I want to know why a Time Limit shield can
  prevent interacting with Spill.
- As a user, I want a direct way to open the relevant Screen Time settings.
- As a maintainer, I want automated verification that the Spill click route still
  works independently from manual Screen Time state.

## UX Requirements

### Entry Point

Preferences include a compact Screen Time compatibility note and an Open Screen
Time button.

### Layout

The note lives in General preferences near launch behavior.

### States

- loading: not applicable.
- empty: not applicable.
- unavailable: if System Settings cannot open, the app silently falls back to no
  action.
- permission required: no new permission.
- success: System Settings opens to Screen Time.
- failure: docs describe manual Screen Time navigation.

## Functional Requirements

1. Add a public-API Screen Time settings opener.
2. Add a preferences note explaining App Limits, Downtime, Always Allowed, and
   independent app launch.
3. Add README troubleshooting guidance.
4. Keep status-click smoke verification available.

## Behavior Scenarios

### Spill Limited

Given Spill is blocked by Screen Time
When the user wants to use Spill
Then the README instructs them to add Spill to Always Allowed or disable the
relevant limit.

### Launcher Limited

Given a terminal or another launcher app is blocked by Screen Time
When Spill appears not to react during manual testing
Then docs instruct the user to clear the launcher shield and launch Spill as its
own app from Applications/Finder.

### Preferences

Given the user can open Preferences
When they press Open Screen Time
Then System Settings opens to Screen Time.

## Acceptance Criteria

- Preferences include Screen Time compatibility guidance.
- README includes a troubleshooting section for App Limits and Downtime.
- `./scripts/verify-status-click-smoke.sh` passes.
- Standard unit/build/workflow checks pass.

## Metrics

- perceived latency: no runtime impact.
- reliability: users have a documented path for OS-level blocks.
- resource use: no polling.

## Rollout

- MVP: settings link, README guidance, verification record.
- later: add a release-site troubleshooting note if public users report the same
  issue.

## References

- Apple Support: Screen Time App Limits
- Apple Support: Screen Time Downtime
- Apple Support: Screen Time Always Allowed
- `scripts/verify-status-click-smoke.sh`
