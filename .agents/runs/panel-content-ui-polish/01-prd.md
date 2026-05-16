# Detailed PRD: Panel Content UI Polish

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, `Clarity: clear`, and no blocking questions.

## Summary

Refine the compact Spill panel UI using the Stitch panel's content hierarchy while ignoring the unrelated left-side settings mock. The goal is not a new feature surface; it is a clearer hierarchy for the content that already exists.

## Resolved Inputs

- maintainer decisions: ignore the left UI, improve the actual panel content
- repo-researched facts: the current panel already exposes CPU, memory, storage, AI status, window actions, menu bar actions, Sleep Guard, Settings, and Quit
- assumptions: a tighter header, clearer section bands, and a more readable footer are enough for this pass

## Goals

- Make the panel read as one compact control tray rather than disconnected small boxes.
- Keep Settings and Quit visible but visually secondary to current state.
- Improve status row hierarchy and graph readability.
- Make AI, window actions, menu bar actions, and footer controls easier to scan.
- Preserve current provider behavior and refresh cadence.

## Non-goals

- Implementing the left-side Stitch settings/navigation mock.
- Adding new provider data.
- Adding large charts or dashboards.
- Adding new permissions.

## User Stories

- As a user, I want the panel to show the important content immediately without visual clutter.
- As a user, I want Settings and Quit to be easy to find but not dominate the panel.
- As a user, I want the status rows and graphs to feel intentional and readable.
- As a user, I want action rows to feel like commands, not decorative placeholders.

## UX Requirements

### Entry Point

The same menu bar trigger opens the panel. No new entry point is introduced.

### Layout

- Header contains app identity, concise state subtitle, status dot, Settings, and Quit.
- Status content remains CPU, Memory, and Storage as a vertical performance stack.
- AI status stays compact and clear.
- Window actions and menu bar actions remain horizontal command surfaces.
- Footer remains a compact strip with Sleep Guard, power, count, and time.

### States

- loading: keep cached or sampling values visible.
- empty: action surfaces show short empty states.
- unavailable: metrics show `N/A` with muted styling.
- permission required: existing Accessibility messaging remains visible.
- success: action feedback remains visible in the header subtitle.
- failure: action feedback remains visible and does not resize the panel unexpectedly.

## Functional Requirements

1. Update SwiftUI panel spacing and grouping without changing provider APIs.
2. Make primary commands visually distinct with icon-first controls.
3. Reduce unnecessary boxed styling where content already has structure.
4. Keep text within bounds at compact panel width.
5. Keep panel smoke verification passing.

## Behavior Scenarios

### Main Path

Given the app is running  
When the user opens the Spill panel  
Then the panel presents current state, status rows, AI statuses, window actions, menu bar actions, and footer controls with clear hierarchy

### Permission State

Given Accessibility is not trusted  
When the user opens the Spill panel  
Then action surfaces still show clear permission-required or empty states without overlap

### Command Visibility

Given the panel is open  
When the user scans the header and footer  
Then Settings, Quit, and Sleep Guard are visible and distinguishable

## Acceptance Criteria

- Panel still opens quickly.
- Settings and Quit are visible.
- Status rows remain CPU, Memory, and Storage with sparklines.
- AI and action sections are compact and readable.
- Footer controls are understandable without oversized decoration.
- `swift test`, `panel-layout-smoke`, workflow verification, and `git diff --check` pass.

## Metrics

- perceived latency: panel appears before heavy refresh work.
- reliability: no provider or settings behavior changes are required.
- resource use: no additional polling or scanning.

## Rollout

- MVP: SwiftUI layout polish only.
- later: screenshot-driven pixel regression if manual UI iteration continues.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/design/stitch.md`
- Stitch screen `Spill Multi-Widget Panel`
