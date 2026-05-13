# Feature Intake

## Feature ID

`single-trigger-reset`

## Request

Remove the fragile multi-item status bar architecture and reset Spill to a single visible menu bar trigger. The current implementation still creates a hidden spacer `NSStatusItem` and derives its width from notch geometry. Modern macOS can hide or clip oversized status items, so this cannot remain the foundation for Spill.

## User Problem

Users need a trigger they can see and click reliably. If Spill depends on a large invisible spacer, the trigger can disappear or end up in an unusable position when the menu bar is crowded.

## Necessity Assessment

- Necessary for current product direction: yes. The compact control tray depends on one reliable entry point.
- Better solved by Spill, macOS, or an existing dedicated app: Spill must solve this by not fighting macOS status item layout.
- Small enough for the compact tray: yes. This only changes the trigger architecture.
- Private API, fragile behavior, or distribution risk: this removes fragile spacer behavior and does not add private APIs.
- Cost of not building it: later panel and provider work remains built on an unreliable entry point.

Decision: `build`

Reason: A single visible trigger is the required baseline before panel and provider work.

## Clarifying Questions

Questions:

- None. The product decision is already documented in the global PRD and ARD.

## Target User

Mac users with crowded menu bars and maintainers building the compact control tray.

## Proposed Product Shape

Spill creates one fixed-width status item with an ellipsis icon. Clicking it toggles the Spill panel, and right-clicking or Control-clicking opens the app menu.

## Constraints

- macOS/public API constraints: `NSStatusItem` placement is controlled by macOS and the user.
- permission constraints: none for the trigger itself.
- distribution constraints: no private APIs.
- performance constraints: no polling or layout recalculation for spacer width.

## Non-goals

- Do not physically move other apps' menu bar icons.
- Do not recover every item hidden behind the notch.
- Do not redesign the panel in this slice.
- Do not remove the best-effort AX scanner.

## Open Questions

- None.

## Decision

Status: `accepted`

Reason: This is the smallest reliable architecture reset.
