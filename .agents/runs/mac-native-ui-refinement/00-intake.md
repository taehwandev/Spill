# Feature Intake

## Feature ID

`mac-native-ui-refinement`

## Request

The user wants a UI overhaul to align strictly with macOS native style. Specifically, they pointed out that the current blue and green colors are hard to see and feel too generic/non-native. They also emphasized following the project workflow.

## User Problem

The current UI uses generic vibrant colors and boxed-in layouts that feel disconnected from the macOS system aesthetic. This makes the app look less "premium" and reduces readability for key status indicators.

## Necessity Assessment

- Necessary for current product direction: yes, aligns with "premium native utility" goal.
- Better solved by Spill: yes, core UI surface.
- Small enough for compact tray: yes.
- Private APIs or new permissions: no.
- If not built: UI remains "AI-like" and suboptimal for native Mac users.

Decision: `build`

Reason: Directly addresses user feedback on aesthetics and readability while reinforcing the project's native-first identity.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none (User confirmed "Follow Mac style").
- researchable: Apple HIG (Human Interface Guidelines) for system colors and materials.
- assumable: Use standard system colors (Indigo, Teal, Graphite, etc.) and native materials (VisualEffectView) instead of custom vibrant palettes.
- out-of-scope: Adding themes system (user wants native style first), non-Mac UI patterns.

Resolved inputs:

- maintainer: Follow Mac style since this is a Mac app.
- repo-research: Current colors are defined in `SpillStatusStyle.swift`.
- assumption: Shift from generic green/blue to native-aligned semantic colors.

## Clarifying Questions

Questions: none

## Target User

Mac users who value a seamless, "first-party" feel in their utilities.

## Proposed Product Shape

A refined panel that uses macOS semantic colors (Indigo for active, Graphite/Secondary for idle, Teal/Green for healthy) and native materials. High contrast where needed, but integrated with the system's "Control Center" look.

## Constraints

- Follow macOS HIG.
- Avoid generic "AI" aesthetic (vibrant neon greens/blues).
- Preserve compact height.

## Non-goals

- Implementing a full theme engine in this pass.
- Changing provider logic.

## Decision

Status: `accepted`

Reason: Clear direction provided by user.
