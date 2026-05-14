# Feature Intake

## Feature ID

`system-memory-provider`

## Request

Add the first real system status provider to Spill without fake metrics. The compact panel currently shows panel state and action count, but the product direction calls for useful Mac status in the same surface. This feature should add memory usage using public macOS APIs and show it in the panel.

## User Problem

Users want the panel to be more than a hidden-icon tray. A small real system status signal makes Spill more useful while preserving the compact design. Memory usage is a safe first provider because it can be read locally without Accessibility, Screen Recording, network access, private APIs, or background sampling.

## Necessity Assessment

Decision: `build`

Reason:

This feature is necessary as the first real status provider and a concrete test of the provider model. It is limited to memory usage because CPU requires sampling and battery requires IOKit power source handling that should be scoped separately. The implementation is small, testable, and distributable.

## Clarifying Questions

No maintainer question blocks this memory-only slice. CPU, battery, AI, and window-management providers remain separate features and must not be added here.

## Target User

- Mac users who want compact system status near hidden menu bar actions.
- Contributors validating the provider architecture with real data.
- Maintainers avoiding fake dashboard metrics.

## Proposed Product Shape

The panel `STATUS` section shows a real `MEMORY` meter and the existing `ACTIONS` meter. Accessibility state remains visible in the panel footer and permission-required panel state.

## Constraints

- macOS/public API constraints: use public Darwin Mach host statistics and Foundation only.
- permission constraints: no new permission prompts.
- distribution constraints: no private APIs, helper processes, or sampling daemons.
- performance constraints: read memory synchronously and cheaply when the panel renders.

## Non-goals

- No CPU provider.
- No battery provider.
- No network or AI status.
- No provider registry.
- No timers or polling.
- No fake sample values.
- No visual redesign beyond replacing the temporary access meter.

## Open Questions

- Whether memory should later refresh on a timer while the panel is visible.
- Whether system provider data should later be routed through a provider registry.

## Decision

Status: `accepted`

Reason: A memory-only provider gives Spill real system status with low implementation and distribution risk.
