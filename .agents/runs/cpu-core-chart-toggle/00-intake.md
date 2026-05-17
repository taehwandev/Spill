# Feature Intake

## Feature ID

`cpu-core-chart-toggle`

## Request

Add a separate Preferences toggle that lets users show CPU activity by logical core. When enabled, the compact panel CPU row should expose all CPU cores in the chart area instead of only the aggregate CPU sparkline. Also fix misleading CPU `0%` display so sampling and very small non-zero activity are not presented as a true zero.

## User Problem

Users with many CPU cores need to know whether work is spread across cores or concentrated on a few hot cores without expanding Spill into a large monitoring dashboard. The current aggregate CPU chart hides that shape. The current `0.0%` sampling display can also look like a real measurement even when the provider is still collecting its first sample.

## Necessity Assessment

- Product fit: yes, because CPU is an existing compact status metric and this keeps the information inside the existing row footprint.
- Best owner: Spill, because this controls the panel status presentation and Preferences.
- Compactness: yes, if the per-core view replaces the existing CPU sparkline with compact bars rather than adding rows.
- API and distribution impact: no private API or new permission is required; macOS exposes per-processor CPU ticks through public Mach host APIs.
- Cost of skipping: CPU status remains less useful on multi-core Macs and the `0%` sampling ambiguity remains.

Decision: `build`

Reason: The maintainer clarified that the feature means a separate Preferences on/off for showing CPU core status in the panel.

## Ambiguity Gate

Use `.agents/workflows/ambiguity-gate.md` before PRD authoring.

Clarity: `clear`

Unknown classification:

- blocker: None.
- researchable: Existing CPU provider shape, Preferences structure, panel chart renderer, and public macOS CPU APIs.
- assumable: The MVP should keep the compact row footprint and use one compact bar per logical core in the existing chart slot; CPU detail popover should summarize core count and peak core rather than listing every core as text.
- out-of-scope: Large dashboard charts, per-core menu bar text, per-core process attribution, or private API sampling.

Resolved inputs:

- maintainer: Add a Settings/Preferences on/off for exposing CPU core status; CPU has many cores and the chart should change when enabled.
- repo-research: CPU currently uses aggregate `HOST_CPU_LOAD_INFO`; panel status rows have a fixed compact chart slot; Preferences already hosts status display controls; Stitch settings and panel screens support compact controls, not dashboard expansion.
- assumption: Logical CPU cores are the right unit for MVP because public APIs expose logical processor load.

If clarity is `needs-clarification`, ask only the blocking questions below and stop before writing `01-prd.md`.

## PRD Authoring Gate

All blocking inputs are clear: user intent, expected behavior, UI scope, feasibility, permission impact, and distribution impact.

## Clarifying Questions

Questions:

- None.

## Target User

Mac users who rely on the compact panel for quick CPU status and want to see whether CPU activity is spread across many cores or concentrated on a subset.

## Proposed Product Shape

Preferences includes a CPU core chart toggle. When off, the CPU row uses the existing aggregate sparkline. When on, the CPU row uses the same chart area to render all logical cores as compact current-usage bars.

## Constraints

- macOS/public API constraints: use public Mach host processor information APIs.
- permission constraints: no new permissions.
- distribution constraints: no private API or entitlement change.
- performance constraints: keep sampling conservative and cap history length.

## Non-goals

- Per-core process attribution.
- Per-core menu bar summary.
- Large CPU dashboard or expanded panel layout.
- Per-core text rows for every logical CPU.

## Open Questions

- Later slices can decide whether the CPU detail popover should include a larger per-core chart.

## Decision

Status: `accepted`

Reason: This is a compact status enhancement with clear settings ownership and feasible public API implementation.
