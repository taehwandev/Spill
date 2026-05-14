# Feature Intake

## Feature ID

`stitch-panel-shell`

## Request

Use the Stitch panel reference as the visual direction for Spill's compact menu bar panel. The current app already has a working trigger and Accessibility-backed action list, but the panel needs a cleaner theme and visible state treatment. The implementation should make the panel feel useful without pretending to show CPU, memory, battery, AI, or provider data that the app cannot currently source.

## User Problem

Users need to understand what Spill can do before clicking hidden menu bar actions. A plain row of icons does not explain whether Accessibility is ready, whether scanning is happening, or whether actions are available. A compact stateful shell makes the current product easier to trust while keeping room for future system, AI, and window-management providers.

## Necessity Assessment

Decision: `build`

Reason:

This feature is necessary for the current product direction because the panel is the main surface where Spill will eventually combine hidden menu bar actions, system status, AI status, and window actions. The work is small enough for the compact tray when limited to a shell and current app state. It uses public SwiftUI/AppKit APIs and does not require private menu bar APIs, screen capture, network access, or fragile status item manipulation.

## Clarifying Questions

No maintainer question blocks this shell. Real CPU, memory, battery, AI, and window-management providers remain separate features and must be confirmed before data is rendered in the panel.

## Target User

- Mac users who want a compact, polished overflow panel for menu bar actions.
- Open-source contributors who need a clear UI direction before provider work.
- Maintainers validating that Spill remains distributable without private APIs.

## Proposed Product Shape

The panel becomes a compact glass-style control surface inspired by the Stitch `Spill Multi-Widget Panel` screen. It includes a header with current Spill state, two status meters backed by real app state, a horizontal action strip for detected menu bar actions, and a footer with compact status indicators. Missing or unavailable data is shown as permission, scanning, or empty states rather than fake system metrics.

## Constraints

- macOS/public API constraints: use SwiftUI, AppKit, NSPanel, NSVisualEffectView, and existing Accessibility scanner only.
- permission constraints: do not request new permissions; reflect Accessibility readiness only.
- distribution constraints: avoid private APIs, method swizzling, screen capture, and menu bar item relocation hacks.
- performance constraints: keep the panel static and lightweight; no polling loops or new provider timers.
- design constraints: map Stitch sections to native components and keep the panel compact enough for a notch-adjacent surface.

## Non-goals

- No real CPU, memory, battery, AI, or window-management providers.
- No fake provider values.
- No preferences redesign.
- No changes to the status item trigger or spacer behavior.
- No private API or screen capture based menu bar mirroring.
- No broad theme system.

## Open Questions

- Which real provider should replace the temporary `ACTIONS` meter first.
- Whether the future provider panel should support multiple layout modes or a single compact layout.
- Whether the settings sidebar from Stitch should become a separate preferences redesign.

## Decision

Status: `accepted`

Reason: The shell improves the current user-facing panel while preserving the public-API product boundary and leaving real provider data for scoped follow-up features.
