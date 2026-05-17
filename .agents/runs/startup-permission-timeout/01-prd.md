# Detailed PRD: Startup Permission Timeout

## PRD Authoring Gate

`00-intake.md` has `Decision: build` and `Clarity: clear`.

## Summary

Make Spill launch independently from optional Accessibility-dependent focused
window lookup. The app should create its status item and become usable even when
Accessibility is untrusted, unavailable, slow, or waiting on a system prompt.

## Resolved Inputs

- maintainer decisions: startup must not fail because macOS permission or
  timeout behavior gets involved.
- repo-researched facts: the app constructs `WindowActionStore` during
  `AppDelegate` startup, and the store previously performed an immediate
  focused-window refresh.
- assumptions: showing permission-required window action states before focused
  window availability is acceptable and matches existing permission boundaries.

## Goals

- Remove launch-time focused-window AX reads.
- Keep window action state accurate after explicit refresh or user action.
- Return permission-required results without invoking the focused-window
  controller when Accessibility is untrusted.
- Preserve existing panel and shortcut behavior for trusted systems.

## Non-goals

- Remove the Accessibility permission requirement for window movement.
- Add new visible UI.
- Change menu bar scanning behavior.
- Change system sleep or Do Not Disturb behavior.

## User Stories

- As a user without Accessibility permission, I want Spill to open so I can see
  the trigger and permission-required states.
- As a user on a slow or restricted system, I want startup to remain responsive
  even if focused-window lookup is unavailable.
- As a maintainer, I want tests that prevent launch-time focused-window reads
  from coming back.

## UX Requirements

### Entry Point

No new entry point. The menu bar trigger should appear during normal launch.

### Layout

No layout changes. Existing window actions can start in permission-required or
disabled states.

### States

- loading: app startup should not wait on focused-window lookup.
- empty: no focused window should disable window actions after trusted refresh.
- unavailable: unsupported window actions return unavailable/failed results
  after invocation.
- permission required: window actions show Accessibility permission-required
  states when Accessibility is untrusted.
- success: trusted systems can refresh focused-window state and perform actions.
- failure: untrusted systems return `.permissionRequired("Accessibility")`
  without calling the controller.

## Functional Requirements

1. `WindowActionStore` initialization must not read the focused window.
2. `WindowActionStore.refresh()` must skip focused-window lookup when
   Accessibility is untrusted.
3. `WindowActionStore.perform(_:)` must return a permission-required result
   before calling focused-window movement when Accessibility is untrusted.
4. Focused-window control should be injectable for unit testing.
5. Runtime smoke checks must continue to pass after the startup change.

## Behavior Scenarios

### Startup Without Accessibility

Given Accessibility is untrusted
When Spill launches
Then the app initializes without focused-window lookup and window actions are
permission-required.

### Refresh With Accessibility

Given Accessibility is trusted
When the window action store refreshes
Then the store may query the focused window and enables window actions only when
a usable focused window exists.

### Perform Without Accessibility

Given Accessibility is untrusted
When a window action is performed
Then Spill returns `.permissionRequired("Accessibility")` and does not call the
focused-window controller.

## Acceptance Criteria

- Unit tests prove initialization does not read the focused window.
- Unit tests prove untrusted refresh and perform paths skip the controller.
- `swift test`, `swift build`, bundled build, runtime smoke, and panel smoke
  checks pass.
- Panel accessibility smoke remains stable after the faster startup path.

## Metrics

- perceived latency: app should reach smoke-ready state within existing runtime
  smoke limits.
- reliability: no startup dependency on focused-window AX lookup.
- resource use: no new polling or background work.

## Rollout

- MVP: remove launch-time AX focused-window lookup and add regression tests.
- later: continue extracting permission clients behind the lightweight feature
  store architecture.

## References

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Providers/WindowActionProvider.swift`
- `Tests/SpillTests/WindowActionStoreTests.swift`
- `scripts/verify-panel-layout-smoke.sh`
