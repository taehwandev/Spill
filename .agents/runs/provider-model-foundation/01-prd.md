# Detailed PRD: Provider Model Foundation

## Summary

Provider Model Foundation adds plain shared model and protocol contracts for future Spill providers. It introduces the product-facing concepts of `SpillStatusItem` and `SpillAction`, plus provider protocols that can supply those values, while preserving the current menu bar and panel behavior. The feature is successful only if it creates reusable foundations without changing what users see or how the app behaves.

## Goals

- Define stable plain models for status items and actions.
- Define provider protocols that can be implemented by system, AI, pinned app, and window providers later.
- Keep the contracts small enough to be reviewed and tested without UI work.
- Preserve all existing UI behavior.
- Enable future provider and panel work to proceed with clearer file ownership.

## Non-goals

- Build or redesign provider-backed UI sections.
- Add real system metrics, AI status checks, or window controls.
- Execute new user actions from the panel.
- Add new settings or persistence.
- Change current `StatusItemController`, `SpillBarView`, scanner, or panel behavior unless a future implementation task explicitly requires a compile-only adapter.

## User Stories

- As a Spill user, I want the app to behave the same after this foundation lands.
- As a provider implementer, I want one obvious model for status values so system and AI providers do not invent separate shapes.
- As a provider implementer, I want one obvious model for actions so pinned items and window actions can share identity, labels, enabled state, and execution metadata.
- As a reviewer, I want provider protocols to make threading, refresh, and failure semantics visible.

## UX Requirements

### Entry Point

No new entry point. Users continue to click the existing Spill menu bar trigger.

### Layout

No layout change. The existing panel must remain visually and behaviorally unchanged.

### States

- loading: no new loading state is introduced.
- empty: existing empty states remain unchanged.
- unavailable: provider models may represent unavailable values, but no new UI is shown in this feature.
- permission required: provider models may represent permission-gated capabilities, but permissions are not requested or surfaced differently.
- success: existing interactions continue to succeed as before.
- failure: provider contracts should allow errors to be represented or thrown, but no new failure UI is introduced.

## Functional Requirements

1. Define `SpillStatusItem` as a plain value type suitable for display by future panel sections.
2. Define `SpillAction` as a plain value type suitable for representing a future command, shortcut, pinned item, or window action.
3. Define provider protocols for reading status items and actions without coupling providers to SwiftUI views.
4. Include identity and ordering semantics so UI diffing can be deterministic later.
5. Include enabled/unavailable metadata so future UI can show disabled actions without provider-specific branching.
6. Keep provider contracts testable without launching the app.
7. Avoid any user-visible behavior change.
8. Keep existing build behavior intact.

## Acceptance Criteria

- `swift build` passes after implementation.
- Existing app launch behavior is unchanged.
- Existing status item trigger behavior is unchanged.
- Existing panel contents and layout are unchanged.
- New models compile independently of AppKit view code where practical.
- Provider protocols are documented enough for future implementers to understand expected refresh and action semantics.
- No new permission prompts appear.

## Metrics

- perceived latency: no measurable change to panel open time.
- reliability: no new crashes or behavior changes in existing panel/status item flows.
- resource use: no new polling, timers, background tasks, or network calls in this feature.
- implementation quality: future providers can conform without editing UI files first.

## Rollout

- MVP: add plain model types and provider protocols with compile coverage.
- later: add placeholder providers and adapters from existing scanner snapshots.
- later: connect provider output to panel sections.
- later: add real system, AI, pinned action, and window action providers.

## References

- `.agents/runs/example-control-tray/01-prd.md`
- `.agents/runs/example-control-tray/02-ard.md`
- `Sources/Spill/MenuBar/MenuBarItemSnapshot.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
