# Feature Intake

## Feature ID

`panel-fallback-launcher`

## Request

Add a reliable way to open the Spill panel when the menu bar trigger is hard to see or hidden in a crowded menu bar. The app already has a global shortcut, but the preferences window is the most visible recovery surface during setup and troubleshooting. This feature should expose panel opening and refresh controls without changing the single status item architecture.

## User Problem

Spill is useful only if users can open the panel and verify what it is doing. On notched or crowded menu bars, the status item can still be difficult to notice even after avoiding spacer hacks. A fallback launcher makes the app testable and usable while staying inside public macOS APIs.

## Necessity Assessment

Decision: `build`

Reason:

This feature is necessary because it addresses the immediate verification gap without returning to fragile menu bar manipulation. It is small, uses public AppKit and SwiftUI APIs, and does not need new permissions. It also improves setup because Accessibility can be requested and checked from the same visible window.

## Clarifying Questions

No maintainer question blocks this feature. The intended fallback is limited to preferences and the normal app menu; it does not add floating launchers, private APIs, or a second status item.

## Target User

- Users testing Spill when the menu bar trigger is not obvious.
- Maintainers verifying panel UI without relying only on the status item.
- Contributors diagnosing Accessibility and scanner state.

## Proposed Product Shape

Preferences gains a compact control section with current state and action buttons. Users can open the panel, refresh detected items, and access Accessibility settings from a visible window. The macOS app menu also exposes panel, refresh, preferences, and quit actions while the app is active.

## Constraints

- macOS/public API constraints: use AppKit menu APIs and SwiftUI preferences controls only.
- permission constraints: do not request new permission types.
- distribution constraints: no private APIs, screen capture, menu bar item relocation, or helper process.
- performance constraints: no polling or timers.
- UI constraints: keep preferences compact and stateful; do not add tutorial text.

## Non-goals

- No second status item.
- No floating desktop launcher.
- No menu bar spacer revival.
- No private API menu bar management.
- No provider registry.
- No real system, AI, or window providers.

## Open Questions

- Whether a future build should offer a Dock-only or menu-bar-only mode.
- Whether a future visual verification mode should open the panel automatically for screenshots.

## Decision

Status: `accepted`

Reason: A preferences and app-menu fallback improves practical verification while preserving the current public-API architecture.
