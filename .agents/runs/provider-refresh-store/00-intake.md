# Feature Intake

## Feature ID

`provider-refresh-store`

## Request

Continue building Spill toward a useful compact control tray. Memory and power providers now exist, but `SpillBarView` reads them directly during SwiftUI rendering. Add a small provider refresh store so views consume cached provider state and future providers can share a clear refresh cadence.

## User Problem

As system, AI, and window providers grow, direct provider reads inside views can cause repeated work, inconsistent refresh timing, and harder testing. A store gives the panel a stable state source and makes the next provider work safer.

## Necessity Assessment

Assessment:

- Product fit: required before CPU, network, and AI status add more read paths.
- Ownership: this is internal Spill architecture, not an OS-level feature.
- Compactness: no new UI surface is added.
- Distribution safety: no private APIs and no new permissions.
- Deferral cost: future providers will duplicate refresh logic or do work during view rendering.

Decision: `build`

Reason: This is a small architecture step that keeps the compact panel responsive as provider count grows.

## Clarifying Questions

Ask the maintainer before implementation if any of these are unclear:

- user intent
- expected behavior
- feature value
- UI scope
- permission or distribution implications

Questions:

- None for this slice. The scope is internal state plumbing only.

## Target User

Maintainers and contributors adding providers. End users benefit indirectly through a more responsive panel.

## Proposed Product Shape

No visible design change is required. The panel should continue to show memory and power status, but those values should come from a cached store refreshed on panel creation and appearance.

## Constraints

- macOS/public API constraints: keep provider reads public API only.
- permission constraints: no new permissions.
- distribution constraints: keep direct distribution and notarization path unchanged.
- performance constraints: avoid background work when the panel is not constructed; make refresh explicit and testable.

## Non-goals

- Do not add CPU, network, or AI providers in this run.
- Do not add settings UI.
- Do not add a long-lived background daemon.
- Do not change menu bar trigger behavior.

## Open Questions

- Whether a future provider registry should support async provider fan-out and error reporting.

## Decision

Status: `accepted`

Reason: The feature is necessary for near-term provider expansion and has a narrow, low-risk scope.
