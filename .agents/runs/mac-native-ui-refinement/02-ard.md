# Detailed ARD: Mac Native UI Refinement

## Architecture Summary

This pass refines the color management system to use native-aligned semantic colors. It also polishes the application of these colors across the panel components.

## Decisions

### D1: Semantic Color Mapping

Decision:

Modify `SpillStatusState.panelTint` to return system-standard colors or highly visible native-aligned variants.

Rationale:

Centralizing color decisions in `SpillStatusStyle.swift` ensures consistency across the app. Using system-aligned colors reduces the "third-party AI" look.

Alternatives considered:

- Hardcoding colors in each view. Rejected for lack of maintainability.
- Using a full theme engine. Rejected as over-engineered for this MVP pass.

### D2: Visibility and Contrast

Decision:

Increase contrast for status labels by using heavier font weights or secondary background highlights if needed. Use Apple's system palette (e.g., `.teal` for normal, `.indigo` for active) which is designed for accessibility.

Rationale:

The user reported visibility issues with the current colors. System colors are optimized for macOS backgrounds (Light/Dark).

### D3: Removal of Non-Native Decorations

Decision:

Remove unnecessary neon/vibrant overlays or custom symbols that contribute to the "too AI" feel.

Rationale:

Strictly follows the maintainer's Mac-native direction.

## Modules Affected

- `Sources/Spill/Panel/SpillStatusStyle.swift` (Primary mapping)
- `Sources/Spill/Panel/SpillBarView.swift` (Status row rendering)
- `Sources/Spill/Panel/SpillFooterView.swift` (Badge rendering)
- `Sources/Spill/Panel/SpillActionViews.swift` (Action button highlights)

## New Types / APIs

No new types or APIs.

## Data Flow

```text
Status Provider -> SpillStatusState -> SpillStatusStyle.panelTint (System Palette) -> SwiftUI View
```

## Failure Modes

- System colors might look different in older macOS versions (Spill targets macOS 14+).
- High contrast might feel "loud" if not balanced.

## Test Strategy

### Automated

- `swift build`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`

### Manual

- Verify color appearance in both Light and Dark modes.
- Verify visibility of "Normal", "Active", and "Warning" states.
- Confirm "too AI" feeling is reduced.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Update Color Mapping | builder | `SpillStatusStyle.swift` | no |
| Refine Component Colors | builder | `SpillBarView.swift`, `SpillFooterView.swift`, `SpillActionViews.swift` | no |
| Verify and Closeout | builder | run docs | no |
