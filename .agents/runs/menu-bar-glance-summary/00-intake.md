# Feature Intake

## Feature ID

`menu-bar-glance-summary`

## Request

Define the real macOS menu bar glance summary that appears near the system clock area through Spill's single public `NSStatusItem`. The summary must be brief enough for the menu bar and must not turn into a dashboard string. The maintainer called out that CPU, memory, GPU, network, and AI each need product justification before being shown in this constrained surface.

Maintainer clarification received:

- The default glance set should be CPU and memory only.
- The panel should let the user choose the activation criteria for what appears in the menu bar glance.
- Numeric formatting must be configurable because some users may want percentages while others may want one-decimal values.
- GPU should not be shown by default unless Spill can expose a status that is actually meaningful.
- Sleep Guard and Magnet-like window movement are panel actions, not menu bar glance defaults.
- CPU, memory, and AI should always remain visible in the panel.
- The menu bar glance should use simple percent-style display for CPU and memory, with no extra availability labels or budget strings.
- AI should be excluded from the menu bar glance for this development slice because real active usage detection requires reliable usage events, not only process presence or app-open detection.

## User Problem

Users need a tiny always-visible signal, not a long panel compressed into the menu bar. Showing too many labels or too much precision wastes scarce menu bar space and makes Spill feel unusable. The feature needs an explicit decision on which signals are valuable at a glance and how much precision is appropriate.

## Necessity Assessment

- Product fit: yes, a glanceable status item is part of the current direction.
- Best owner: Spill can own a tiny summary for its own providers, while macOS still owns status item placement.
- Compactness: yes, if the menu bar output stays tightly scoped.
- API and distribution impact: no private APIs, fragile behavior, or new permissions if it stays inside the existing single `NSStatusItem`.
- Cost of skipping: Spill either stays icon-only or risks showing a crowded, low-value menu bar string.

Decision: `build`

Reason: The maintainer clarified that the menu bar glance should focus on CPU and memory only for this slice. AI, GPU, network, Sleep Guard, and window actions remain in the panel or future slices.

## PRD Authoring Gate

Clarification is resolved for this slice.

## Clarifying Questions

Questions:

- None for this slice.

## Target User

Users who want a tiny CPU and memory glance signal while working without opening the Spill panel.

## Proposed Product Shape

The expected shape is a short text summary inside the existing single status item, such as `CPU 20%  MEM 56%`. The default summary uses CPU and memory only. Detailed readings, AI, GPU device details, Sleep Guard, and window movement actions remain in the panel.

## Constraints

- macOS/public API constraints: Spill can create one normal `NSStatusItem`, but macOS controls its position near other menu bar extras and the system clock.
- permission constraints: no new permissions for this surface.
- distribution constraints: no private menu bar APIs and no second status item.
- performance constraints: reuse the existing conservative refresh loop.

## Non-goals

- No long dashboard string in the menu bar.
- No forced placement inside or beyond the system clock area.
- No second menu bar status item.
- No fake GPU usage or fake memory availability.
- No GPU menu bar default unless the signal becomes meaningful enough for a glance surface.

## Open Questions

- None for this slice.

## Decision

Status: `accepted`

Reason: Scope is now clear enough for a small implementation slice.
