# Feature Intake

## Feature ID

`screen-time-app-limits`

## Request

The maintainer clarified that iTerm was only an example of the real issue:
macOS Screen Time App Limits or Downtime can put a system Time Limit shield over
apps and interfere with manual Spill usage. Spill cannot bypass Apple's
system-enforced Screen Time controls, but it should document the limitation,
provide a direct settings entry point, and make verification independent from a
limited parent app.

## User Problem

Users can think Spill is broken when macOS is actually blocking either Spill or
the app used to launch/test it. The app needs an explicit compatibility path for
Screen Time rather than treating it as an unrelated terminal problem.

## Necessity Assessment

- Product fit: Spill is a menu bar utility and must explain OS-level conditions
  that can prevent interaction.
- Better owner: macOS enforces Screen Time, but Spill owns diagnostics and docs.
- Surface size: a compact preferences note and README troubleshooting section.
- Platform risk: no private APIs and no Screen Time bypass.
- Cost of deferral: users can misdiagnose Screen Time shields as Spill click
  failures.

Decision: `build`

Reason: Provide a clear, public-API-compatible mitigation path without trying to
override Screen Time.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none.
- researchable: Apple Screen Time App Limits, Downtime, and Always Allowed
  behavior.
- assumable: opening the top-level Screen Time settings pane is sufficient
  because deep-linking subpanes is not a documented stable app API.
- out-of-scope: bypassing Screen Time, adding Screen Time entitlements, or
  managing another user's restrictions.

Resolved inputs:

- maintainer: iTerm is just an example; solve Screen Time interference generally.
- repo-research: status-click smoke now verifies Spill's own status item click
  route.
- Apple docs: App Limits and Downtime can block apps; Always Allowed can allow
  apps after limits or during downtime.
- assumption: users must configure Screen Time themselves because third-party
  utility apps cannot make themselves Always Allowed.

## PRD Authoring Gate

Decision is `build` and clarity is `clear`.

## Clarifying Questions

Questions:

- none.

## Target User

Users running Spill on Macs with Screen Time App Limits, Downtime, or app
category limits enabled.

## Proposed Product Shape

Preferences should include a concise Screen Time compatibility note with a
button to open Screen Time settings. README should explain that users should add
Spill to Always Allowed or disable the relevant App Limit, and that development
testing should not depend on a blocked launcher app.

## Constraints

- macOS/public API constraints: use `NSWorkspace` to open System Settings only.
- permission constraints: no new app permissions.
- distribution constraints: no signing or entitlement changes.
- performance constraints: no runtime polling.

## Non-goals

- Bypass App Limits or Downtime.
- Request Screen Time API entitlements.
- Detect every active Screen Time shield.
- Change panel behavior.

## Open Questions

- none.

## Decision

Status: `accepted`

Reason: Screen Time is an OS-level control; Spill should provide a stable
mitigation path and avoid unsupported bypasses.
