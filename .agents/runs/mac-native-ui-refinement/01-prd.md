# Detailed PRD: Mac Native UI Refinement

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, `Clarity: clear`, and no blocking questions.

## Summary

Refine the Spill UI to strictly follow macOS native aesthetics. Replace generic "AI-like" vibrant blue/green colors with macOS semantic colors (Indigo, Teal, Graphite). Improve visibility of status indicators and unify the design language with the system Control Center.

## Resolved Inputs

- maintainer decisions: Follow Mac style strictly.
- repo-researched facts: Colors are managed via `SpillStatusState.panelTint` in `SpillStatusStyle.swift`.
- assumptions: Using Apple's semantic system colors will solve the "AI-like" and "low visibility" issues.

## Goals

- Eliminate generic "AI-style" neon colors.
- Use macOS native-aligned color palette (Indigo, Teal, Graphite, Orange, Secondary).
- Improve visibility of "Normal" and "Active" states.
- Ensure the app feels like a first-party macOS utility.

## Non-goals

- Adding a theme picker UI in this pass.
- Changing functional behavior of status providers.
- Changing panel layout structure.

## User Stories

- As a Mac user, I want Spill to feel like a native part of the OS, not a third-party AI tool.
- As a user, I want status colors (Green/Blue) to be highly visible against the panel background.
- As a user, I want the UI to be professional and integrated with the system's design language.

## UX Requirements

### Visual Language

- Use **Teal** or **Mint** instead of generic Green for healthy/normal states.
- Use **Indigo** or **Blue** (System) instead of generic Blue for active/primary states.
- Use **Graphite** or **Secondary** for idle/unavailable states.
- Ensure text contrast ratios meet macOS accessibility standards.

### Hierarchy

- Focus on clear status badges.
- Use system-standard font weights.

## Functional Requirements

1. Update `SpillStatusStyle.swift` to use a refined native color palette.
2. Refine `SpillBarView.swift` and `SpillFooterView.swift` to ensure color application is consistent.
3. Ensure dark/light mode compatibility (using system semantic colors).

## Behavior Scenarios

### Native Color Palette

Given the panel is open  
When a status is "Normal"  
Then it should use a professional Teal/Mint color that is highly visible.

### Active State

Given the panel is open  
When a status or action is "Active" or "Primary"  
Then it should use a native Indigo/Blue color that feels integrated with macOS.

## Acceptance Criteria

- Blue/Green colors are replaced with refined, native-like versions.
- UI no longer feels "too AI-like".
- Visibility of status labels is improved.
- `swift build` and `swift run` pass.
- All functional states (Normal, Active, Warning, Unavailable) remain distinguishable.

## Rollout

- MVP: Color palette and tint logic update only.
- Later: Comprehensive material and spacing overhaul if needed.
