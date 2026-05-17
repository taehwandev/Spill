# Feature Intake

## Feature ID

`startup-permission-timeout`

## Request

The maintainer reported that Spill can fail to open when macOS permission or
timeout behavior gets involved. The app must still launch even when
Accessibility-dependent features are unavailable, slow, or blocked by the
system. Permission-dependent window actions should degrade after launch instead
of blocking app startup.

## User Problem

Users cannot trust a menu bar utility if a missing permission or stalled system
query prevents the app from opening. Startup reliability is a baseline
distribution and daily-use requirement.

## Necessity Assessment

- Product fit: launch reliability is required for the compact control tray.
- Better owner: macOS owns permission prompts, but Spill owns when it performs
  permission-dependent work.
- Surface size: no new UI surface is needed.
- Platform risk: this reduces Accessibility risk by avoiding launch-time AX
  focused-window reads.
- Cost of deferral: users may see the app as broken before reaching the trigger
  or permission fallback states.

Decision: `build`

Reason: This is a small reliability fix that keeps startup independent from
optional Accessibility-dependent window features.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none.
- researchable: current app startup path, window action store construction, and
  smoke test timing.
- assumable: the reported timeout is caused by optional launch-time system or AX
  work, so the safest fix is to remove optional AX reads from initialization.
- out-of-scope: changing macOS permission prompts or replacing Accessibility for
  window movement.

Resolved inputs:

- maintainer: app launch must not fail because macOS permission/timeout behavior
  is involved.
- repo-research: `AppDelegate` constructs `WindowActionStore` during startup;
  the store previously refreshed immediately and read the focused AX window.
- assumption: permission-required window action states are acceptable until the
  user grants Accessibility or invokes the feature.

## PRD Authoring Gate

Decision is `build` and clarity is `clear`.

## Clarifying Questions

Questions:

- none.

## Target User

Users launching Spill on a Mac where Accessibility is denied, not decided yet,
or where the focused-window AX lookup is slow or unavailable.

## Proposed Product Shape

Spill should create the menu bar trigger and launch normally. Window quick
actions should show permission-required or disabled states until the feature can
query the focused window safely.

## Constraints

- macOS/public API constraints: keep using public Accessibility APIs for window
  movement.
- permission constraints: do not request or depend on Accessibility before the
  app has launched.
- distribution constraints: startup must work in unsigned, ad-hoc signed, and
  future notarized builds.
- performance constraints: avoid blocking launch on optional AX reads.

## Non-goals

- Remove Accessibility requirements from window actions.
- Add a new onboarding flow.
- Change the panel layout or shortcut behavior.

## Open Questions

- none.

## Decision

Status: `accepted`

Reason: Startup should not depend on optional permission-gated features.
