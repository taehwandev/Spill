# Detailed PRD: Menu Bar Action Adapter

## Summary

The menu bar action adapter maps existing `MenuBarItemSnapshot` values into shared `SpillAction` values. The panel can keep using current scanner execution while rendering action metadata from the provider model. This keeps the user-facing behavior stable and prepares the panel for future provider sections.

## Goals

- Convert current menu bar snapshots into `SpillAction` values.
- Preserve existing action click behavior through `AXMenuBarItemScanner`.
- Add focused tests for adapter identity, title, subtitle, role, state, and source ID recovery.
- Keep the UI visually unchanged except for internal model usage.
- Avoid fake or speculative provider data.

## Non-goals

- Do not implement a provider registry.
- Do not add real system, AI, or window providers.
- Do not replace scanner execution.
- Do not change Accessibility prompts.
- Do not redesign the panel.

## User Stories

- As a contributor, I want menu bar actions represented as `SpillAction` values so future UI sections can share a model.
- As a maintainer, I want tests proving scanner snapshots map into stable action metadata.
- As a user, I want the action strip to keep working the same way.

## UX Requirements

### Entry Point

The existing menu bar trigger and panel action strip remain the entry point. No new visible control is added.

### Layout

The existing Stitch-inspired panel shell remains in place. The action section still shows compact action tiles.

### States

- loading: unchanged scanner-driven scanning state.
- empty: unchanged display-mode-aware empty state.
- unavailable: action state becomes disabled when the source snapshot cannot be pressed.
- permission required: unchanged Accessibility-required state.
- success: enabled mapped actions remain clickable.
- failure: scanner failure messages remain the source of execution failure feedback.

## Functional Requirements

1. Add a `MenuBarActionAdapter` that maps snapshots to actions.
2. Use a deterministic menu bar action ID prefix.
3. Preserve the source snapshot ID in the action ID so scanner execution can continue.
4. Map snapshot `stableKey` into `SpillActionKind.menuBarItem`.
5. Map snapshot `displayTitle` into action title.
6. Map snapshot `ownerName` into action subtitle.
7. Map snapshot `imageData` into action icon data.
8. Mark notch candidates as primary actions and other menu bar actions as secondary actions.
9. Mark non-pressable snapshots as disabled actions.
10. Update the panel action tile to render from `SpillAction` metadata.

## Acceptance Criteria

- `swift build` passes.
- `swift test` passes.
- Workflow gates pass.
- Runtime smoke passes.
- Adapter tests cover enabled and disabled mappings.
- Existing scanner press behavior remains wired by source snapshot ID.
- No new fake provider values are introduced.

## Metrics

- perceived latency: no change because mapping is in-memory.
- reliability: action IDs can recover the source scanner snapshot ID.
- resource use: no new background work.

## Rollout

- MVP: map current scanner snapshots into `SpillAction` and use the model in the panel action button.
- later: introduce a provider registry and route action execution through provider handlers.

## References

- `Sources/Spill/Providers/SpillActionModels.swift`
- `Sources/Spill/MenuBar/MenuBarItemSnapshot.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
