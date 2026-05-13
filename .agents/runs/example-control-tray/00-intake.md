# Feature Intake

## Feature ID

`example-control-tray`

## Request

Create a compact Spill control tray that combines Mac system status, AI tool state, pinned actions, and simple window actions. The panel should be useful without becoming a large dashboard.

## User Problem

Users have too many small utilities and menu bar icons. Some icons are hidden by macOS or the notch, but what users actually need is quick status and action access.

## Necessity Assessment

- Necessary for current product direction: yes. It replaces the fragile hidden-icon recovery promise with a compact tray users can actually rely on.
- Better solved by Spill, macOS, or an existing dedicated app: Spill should solve the small, combined tray use case. Full system monitoring and full window management remain outside scope.
- Small enough for the compact tray: yes, if each section stays row-based and avoids dashboard panels.
- Private API, fragile behavior, or distribution risk: no private APIs are required for the core tray. Accessibility is required only for selected actions.
- What happens if we do not build it: Spill remains tied to a broken spacer workaround and does not become useful enough to distribute.

Decision: `build`

Reason: The feature is the smallest practical product direction that fits public macOS APIs and gives users visible value.

## Clarifying Questions

Questions:

- None for this example run. AI provider defaults and Accessibility-dependent window actions are tracked as scoped product questions.

## Target User

Mac developers and AI-heavy users with crowded menu bars.

## Proposed Product Shape

A small panel opened by one visible menu bar trigger. The panel has compact rows for status, AI, pinned actions, and window actions.

## Constraints

- Use public APIs plus Accessibility only where needed.
- No private menu bar manipulation.
- No giant `NSStatusItem` spacer.
- Must remain distributable outside the Mac App Store.

## Non-goals

- Full iStat Menus clone.
- Full Rectangle clone.
- Guaranteed recovery of every hidden menu bar icon.

## Open Questions

- Which AI providers should be enabled by default?
- Should window actions appear only when Accessibility is trusted?

## Decision

Status: `accepted`

Reason: This matches the revised Spill direction and is technically feasible.
