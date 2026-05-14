# Detailed PRD: Panel Fallback Launcher

## Summary

Spill should expose panel opening and item refresh from visible app surfaces, not only from the menu bar status item. The fallback launcher will add a compact preferences control section and app menu commands. This preserves the single status item design while making the app easier to verify when the menu bar trigger is hidden or overlooked.

## Goals

- Add an `Open Panel` control in preferences.
- Add a refresh control in the same visible section.
- Show compact Accessibility and detected item state in preferences.
- Add app menu commands for panel, refresh, preferences, and quit.
- Keep status item behavior unchanged.

## Non-goals

- Do not add another menu bar item.
- Do not add a floating always-on launcher.
- Do not add new permissions.
- Do not add private menu bar APIs.
- Do not redesign all preferences.

## User Stories

- As a user, I want to open the Spill panel even when I cannot find the menu bar trigger.
- As a user, I want to refresh detection from a visible window.
- As a maintainer, I want a public-API fallback path for panel verification.

## UX Requirements

### Entry Point

The fallback appears near the top of the existing preferences window. The normal app menu also exposes the same core commands while the app is active.

### Layout

The preferences control section includes:

- A small header.
- Accessibility and item count state pills.
- Buttons for opening the panel and refreshing detected items.
- An Accessibility settings button only when access is not trusted.

### States

- loading: refresh button shows `Scanning` and disables while scanner is active.
- empty: item count shows `0`.
- unavailable: refresh disables when Accessibility is not trusted.
- permission required: Accessibility state pill and settings button are visible.
- success: open panel remains available and refresh is enabled.
- failure: existing scanner message remains in the detection section.

## Functional Requirements

1. Preferences must accept an open-panel action.
2. Preferences must render a compact control section above general settings.
3. The open-panel button must call the same panel controller used by the status item.
4. The refresh button must call scanner refresh when Accessibility is trusted.
5. The app menu must include Show Spill Panel, Refresh Menu Bar Items, Preferences, and Quit commands.
6. Existing status item and hotkey behavior must remain unchanged.
7. Runtime smoke must still pass.

## Acceptance Criteria

- `swift build` passes.
- `swift test` passes.
- Workflow gates pass.
- Runtime smoke passes.
- Preferences can call the panel open action.
- App menu commands are configured on launch.
- No status item spacer or private API is added.

## Metrics

- perceived latency: opening the panel should remain immediate.
- reliability: preferences fallback must exist even when the status item is hard to locate.
- resource use: no new background work.

## Rollout

- MVP: preferences control section and app menu commands.
- later: add automated visual verification mode if needed.

## References

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Preferences/PreferencesView.swift`
- `Sources/Spill/Preferences/PreferencesWindowController.swift`
