# Detailed PRD: Token Dashboard Process Surface

## PRD Authoring Gate

Do not author this PRD until `00-intake.md` has `Decision: build` and all clarifying questions are resolved. If lifecycle behavior, packaging impact, shared store access, permissions, or verification is unclear, return to `00-intake.md`, ask the maintainer, and stop here.

## Summary

Make the local token metering dashboard a distinct dashboard surface that can be opened from the menu bar AI glance and, in a later architecture slice, hosted outside the main menu bar app process. The current compact Spill panel remains small and glanceable. The dashboard can become larger, tabbed, and analytic without changing the always-on tray behavior.

## Goals

- Let users enable an AI glance item next to the clock.
- Open the local token dashboard directly when the AI glance is clicked.
- Keep the compact panel from becoming a full dashboard.
- Define a true helper-process dashboard target with independent close and quit behavior.
- Preserve local-only token privacy and existing usage event schema.

## Non-goals

- No login, auth, or cloud sync.
- No web account dashboard.
- No new token event fields.
- No prompt, command, file, log, diff, source, environment, or secret collection.
- No private macOS APIs.

## User Stories

- As a local AI user, I want one click on the menu bar AI item to open token usage details.
- As a menu bar utility user, I want closing or quitting the dashboard view to leave Spill running in the menu bar.
- As a maintainer, I want the process split specified before adding packaging and helper lifecycle complexity.
- As a privacy-conscious user, I want the dashboard process to read only the same safe local token store as the main app.

## UX Requirements

### Entry Points

- Preferences > Status Modules exposes an `AI` menu bar glance toggle.
- The menu bar `AI` glance appears alongside CPU, memory, and caffeine when enabled.
- Left-clicking the `AI` glance opens the local token dashboard directly.
- Clicking the main Spill trigger still toggles the compact panel.
- Right-clicking or Control-clicking the status item still opens the native context menu.

### Dashboard Surface

- The dashboard remains separate from the compact panel.
- Dashboard top-level views may be tabbed when multiple analytics surfaces exist.
- Work item, tool, workflow, stage, source, and model views must keep their current safe-label privacy boundary.
- Unknown raw run ids should not be treated as user-facing task names.

### Close And Quit

- Current-app precursor: closing the dashboard window closes only that window.
- True process target: Command-Q while focused in the dashboard helper quits only the dashboard helper process.
- Command-Q from the main Spill app continues to quit the main menu bar utility only when the main app is focused.
- Relaunching the dashboard from the menu bar reuses an existing dashboard process/window if one is already running.

## Functional Requirements

1. Add an AI menu bar glance item that can be enabled in Status Modules preferences.
2. Route AI glance left-clicks to the local token dashboard action instead of toggling the compact Spill panel.
3. Keep existing caffeine click behavior unchanged.
4. Preserve existing right-click and Control-click menu behavior.
5. Define a future helper process target that reads the app-owned local token store without changing the event schema.
6. The helper process must not own token ingestion, hook installation, app settings mutation, or cloud sync.
7. The main app remains responsible for menu bar presence, ingestion loop, settings, preferences, and adapter setup.
8. The dashboard helper reads imported local store snapshots and can request refresh from the main app only through an explicit local IPC boundary.

## Acceptance Criteria

- Users can enable `AI` in the clock-area status module settings.
- When enabled, the menu bar shows an AI glance item.
- Left-clicking the AI glance opens the local token dashboard.
- Left-clicking other parts of the Spill status item still toggles the compact panel, except caffeine which keeps its current toggle behavior.
- Right-click and Control-click still show the native menu.
- Existing menu bar status tests pass.
- `swift test` passes.
- Web token dashboard formatting tests pass when web formatting is changed in the same feature slice.
- A later helper-process implementation has a separate verification command that proves Command-Q in the helper does not terminate the main app.

## Metrics

- Menu bar AI glance click latency: dashboard opens within 1 second when the main app is already running.
- Dashboard process idle overhead target: below the main app ingestion loop overhead when no dashboard is open.
- Reliability: helper relaunch should recover without requiring a main app restart.

## Rollout

1. Precursor slice: AI menu bar glance and direct dashboard action inside the current app process.
2. PRD/ARD slice: choose helper architecture and shared-store access pattern.
3. Implementation slice: add helper target, launch/reuse behavior, and focused Command-Q semantics.
4. Verification slice: add smoke checks for helper launch, close, Command-Q, and main app survival.

## References

- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Sources/Spill/Preferences/StatusModulesPreferencesSection.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardWindowController.swift`
- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
