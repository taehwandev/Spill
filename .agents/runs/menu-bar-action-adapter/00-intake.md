# Feature Intake

## Feature ID

`menu-bar-action-adapter`

## Request

Continue from the Stitch-inspired panel shell by connecting current menu bar scanner output to the shared `SpillAction` model. The current UI still renders `MenuBarItemSnapshot` values directly, while the provider foundation already defines reusable action contracts. This run should keep behavior unchanged while making the panel consume common action metadata.

## User Problem

Spill is intended to become a compact control surface for hidden menu bar actions, system status, AI status, and window-management actions. If the current menu bar actions stay as scanner-specific UI data, every future provider will need separate rendering and execution glue. A small adapter makes existing actions part of the provider-shaped architecture without adding speculative data.

## Necessity Assessment

Decision: `build`

Reason:

This feature is necessary because it bridges the current working scanner behavior into the provider model before more providers are added. It is small, testable, and does not require new permissions or private APIs. It also avoids user-facing churn because the panel should look and behave the same after the adapter is introduced.

## Clarifying Questions

No maintainer question blocks this adapter. Execution still goes through the existing scanner and does not change the menu bar trigger, Accessibility behavior, or provider roadmap.

## Target User

- Contributors implementing future provider-backed panel sections.
- Maintainers reviewing whether the panel is moving toward a coherent architecture.
- Users indirectly, through lower-risk future additions.

## Proposed Product Shape

No intentional visible product change. The action strip still shows detected menu bar items and clicks them through Accessibility. Internally, each displayed item is mapped into a `SpillAction` with title, subtitle, icon data, kind, role, and enabled state.

## Constraints

- macOS/public API constraints: use existing public AppKit, SwiftUI, and Accessibility flow only.
- permission constraints: do not request new permissions.
- distribution constraints: no private APIs, no screen capture, no menu bar item relocation.
- performance constraints: adapter mapping must be synchronous and cheap.
- architecture constraints: avoid adding real system, AI, or window providers in this slice.

## Non-goals

- No new visual design.
- No real system monitoring provider.
- No AI status provider.
- No window-management provider.
- No new action execution engine.
- No change to scanner discovery.
- No change to status item trigger behavior.

## Open Questions

- Whether future `SpillAction` execution should be routed through a provider registry.
- Whether action IDs need stronger namespacing once multiple providers contribute actions.
- Whether menu bar actions should also become `SpillStatusItem` entries later.

## Decision

Status: `accepted`

Reason: The adapter is a narrow architecture step that keeps the app usable while preparing the panel for real provider-backed features.
