# Detailed PRD: Panel Controls Refresh

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, `Clarity: clear`, and no blocking questions.

## Summary

Improve the panel and menu bar trust loop by making system values update continuously, replacing the low-value GPU status card with storage, adding small panel graphs, exposing Sleep Guard duration configuration, keeping Quit visible in the panel, and fixing Settings icon removal.

## Resolved Inputs

- maintainer decisions: remove GPU from the useful status surface; add storage; draw graphs in the panel; make the panel status area read as three rows; fix Settings icon removal; document before further implementation
- repo-researched facts: current status refresh used the settings refresh interval shared with scanner refresh; Sleep Guard has fixed duration cases; provider/view layers already use plain status models
- assumptions: Storage means primary volume capacity; graphs are compact sparklines, not full historical dashboards

## Goals

- Keep CPU and memory menu bar values moving after the panel closes.
- Replace the primary panel GPU card with storage capacity.
- Present CPU, Memory, and Storage as three clear metric rows in the panel.
- Add compact sparklines for panel metrics without growing into a dashboard.
- Let users choose the default Sleep Guard duration in Preferences.
- Provide a visible panel Quit control.
- Make Settings icon removal work and persist.

## Non-goals

- Full disk throughput monitoring.
- Full GPU monitoring.
- Full iStat-style charts.
- Arbitrary custom Sleep Guard duration text entry.
- Additional permissions.

## User Stories

- As a user, I want CPU and memory in the menu bar to keep changing so I know Spill is live.
- As a user, I want storage in the panel because it is more useful than the current GPU card.
- As a user, I want panel graphs so I can understand trend, not only the current number.
- As a user, I want to configure Sleep Guard time instead of repeatedly picking the same duration.
- As a user, I want Settings icon removal to immediately remove the icon and keep it removed.
- As a user, I want to quit Spill from the panel without hunting through a menu.

## UX Requirements

### Entry Point

- Menu bar status chips remain the glance entry point for CPU, memory, and active Sleep Guard.
- The panel footer exposes Sleep Guard and Quit.
- Preferences exposes Sleep Guard duration and icon removal controls.

### Layout

- The panel status area uses three primary rows:
  - CPU
  - Memory
  - Storage
- Each row contains an icon, current value, concise detail, and a compact sparkline.
- GPU is not shown as a primary status row.
- Footer controls remain compact and labeled.

### States

- loading: show current cached value or sampling state while the next sample is pending.
- empty: icon lists show explicit empty state.
- unavailable: metric row shows `N/A` and a muted style.
- permission required: Settings removal and menu bar scanning show existing Accessibility messaging.
- success: Settings icon removal updates UI and persists.
- failure: failed removal or stale item action shows explicit feedback.

## Functional Requirements

1. Menu bar CPU and memory status refresh independently from menu bar item scanning.
2. Panel status refresh continues while the panel is visible even if menu bar status chips are disabled.
3. GPU is removed from the primary panel status modules.
4. Storage status is added using public local volume capacity APIs.
5. Panel CPU, Memory, and Storage rows draw bounded sparklines.
6. Preferences includes a Sleep Guard default duration picker.
7. Panel footer Sleep Guard uses the default duration as the quick start duration.
8. Panel footer includes a visible Quit control.
9. Settings icon removal updates selected item state, persists it, and refreshes visible action lists.

## Behavior Scenarios

### Menu Bar Status Refresh

Given CPU and memory menu bar chips are enabled  
When the panel detail popover is closed  
Then CPU and memory values continue refreshing without waiting for the scanner interval

### Panel Status Rows

Given the user opens the panel  
When status data is available  
Then the panel shows CPU, Memory, and Storage rows with sparklines

### Sleep Guard Duration

Given the user changes the default Sleep Guard duration in Preferences  
When the user starts Sleep Guard from the panel footer quick action  
Then Sleep Guard starts with the configured duration

### Quit From Panel

Given the panel is open  
When the user clicks the Quit control  
Then Spill terminates

### Settings Icon Removal

Given an icon is selected or pinned in Settings  
When the user removes it  
Then it disappears from the panel action list and stays removed after preferences reload

## Acceptance Criteria

- Menu bar CPU and memory values visibly refresh after panel close.
- Panel status area has no GPU primary row.
- Panel includes Storage as a primary row.
- Panel CPU, Memory, and Storage rows include compact sparklines.
- Sleep Guard default duration persists through app restart.
- Panel footer exposes Quit.
- Settings icon removal works immediately and persists.
- `swift test`, `panel-layout-smoke`, and workflow verification pass.

## Metrics

- perceived latency: panel opens before heavy refresh work runs.
- reliability: Settings removal persists in `UserDefaults`.
- resource use: metric history remains bounded and scanner frequency does not increase.

## Rollout

- MVP: fixed Sleep Guard duration picker, storage capacity, simple sparklines, Settings removal fix.
- later: custom duration entry, storage throughput, richer graph controls.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/design/stitch.md`
