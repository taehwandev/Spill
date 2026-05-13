# PRD: Source Folder Layout

## Summary

Organize the Swift source files into folders that match the current architecture boundaries. This is a repository maintenance feature, not a user-facing feature.

## Goals

- Make the codebase easier to scan.
- Make future agent write scopes easier to assign.
- Keep the app behavior unchanged.
- Keep SwiftPM build behavior unchanged.

## User Stories

- As a maintainer, I can find panel UI code without scanning AX and preferences files.
- As a builder agent, I can own a folder-level write scope without touching unrelated modules.
- As a reviewer, I can verify that this slice is a pure move with no behavior changes.

## Proposed Layout

- `Sources/Spill/App`: app entry point, delegate, lifecycle helpers.
- `Sources/Spill/Accessibility`: low-level AX helpers and permission diagnostics.
- `Sources/Spill/MenuBar`: status item trigger, menu bar scanner, item snapshots, notch geometry.
- `Sources/Spill/Panel`: Spill panel controller, layout, metrics, and panel SwiftUI views.
- `Sources/Spill/Preferences`: preferences window and preference sections.
- `Sources/Spill/Settings`: persistent settings and display mode.

## Acceptance Criteria

- Swift files are moved into responsibility-based folders.
- No Swift type names are changed.
- No user-facing behavior is changed.
- `swift build` passes.
- `.agents` docs describe the layout.

## Non-goals

- No single-trigger refactor.
- No provider implementation.
- No panel redesign.
- No preference redesign.

## Success Metrics

- Root `Sources/Spill` contains only folders, not a flat pile of Swift files.
- Future tasks can reference folder-level scopes.
