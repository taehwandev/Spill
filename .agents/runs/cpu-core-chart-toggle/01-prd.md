# Detailed PRD: CPU Core Chart Toggle

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, clarity is `clear`, and no maintainer clarification is required.

## Summary

Add a Preferences toggle that switches the compact panel CPU chart from aggregate CPU history to a per-logical-core bar chart. Keep the CPU row compact, preserve the existing aggregate value text, and make CPU zero display distinguish sampling, tiny non-zero usage, and true zero usage.

## Resolved Inputs

- maintainer decisions: Add a separate Settings/Preferences on/off for exposing CPU core status.
- repo-researched facts: CPU currently reads aggregate host CPU load only; status rows already have a compact 96x28 chart area; Preferences already contains status display controls.
- assumptions: Logical CPU cores are acceptable for MVP; the compact row should not grow when per-core mode is enabled.

## Goals

- Provide a Preferences toggle for CPU per-core chart mode.
- Show all logical CPU cores in the existing CPU row chart area when enabled.
- Keep aggregate CPU value and status state as the primary text.
- Avoid misleading `0%` during sampling or tiny non-zero usage.
- Use public macOS APIs and no new permissions.

## Non-goals

- Add a large CPU dashboard.
- Show every core as a text row.
- Add per-process CPU attribution.
- Add per-core menu bar text.

## User Stories

- As a user, I want to turn on CPU core charting so I can see whether activity is concentrated on a few cores.
- As a user, I want sampling to avoid looking like true `0%` so I can trust the CPU status.

## UX Requirements

### Entry Point

Preferences exposes a CPU core chart toggle in the status display area.

### Layout

The panel CPU row keeps the existing title, aggregate value, subtitle, icon, and row height. When the toggle is off, the row renders the existing aggregate sparkline. When the toggle is on and core samples are available, the chart slot renders one vertical bar per logical CPU core, based on the latest sampled usage for each core.

### States

- loading: CPU value shows `Sampling`; menu bar CPU text shows `--`.
- empty: If no core samples are available, the CPU row falls back to the aggregate sparkline.
- unavailable: CPU value remains `N/A` and chart history does not append.
- permission required: No new permission state.
- success: CPU aggregate value updates, and enabled core chart mode shows all logical cores as compact bars.
- failure: Per-core sample failure does not break aggregate CPU status.

## Functional Requirements

1. Preferences must persist a boolean CPU core chart setting.
2. CPU core chart mode must default off.
3. CPU provider must collect logical core tick samples using public APIs when available.
4. CPU status must include per-core usage ratios for the current sample.
5. System status store must keep bounded per-core history.
6. CPU row must render per-core bars only when the setting is on and core samples exist.
7. CPU row must otherwise render the aggregate sparkline.
8. CPU sampling state must not display as measured `0%`.
9. Tiny non-zero CPU usage must display as less-than text instead of rounded `0%`.

## Behavior Scenarios

### Main Path

Given CPU core chart mode is off
When the panel renders CPU
Then the CPU row shows the aggregate sparkline.

Given CPU core chart mode is on and core samples exist
When the panel renders CPU
Then the CPU row chart shows one compact bar per logical CPU core.

Given CPU is still collecting its first sample
When CPU status is displayed
Then the panel value shows `Sampling` and the menu bar summary uses `--`.

### Relevant Edge States

Given per-core sampling fails but aggregate CPU sampling succeeds
When the panel renders CPU
Then the CPU row falls back to the aggregate sparkline.

Given CPU usage is greater than zero but below display precision
When CPU value is formatted
Then the value displays `<0.1%` or `<1%` depending on precision.

Given CPU active tick delta is exactly zero
When CPU value is formatted
Then the value can display `0.0%` or `0%`.

## Acceptance Criteria

- Preferences exposes and persists CPU core chart mode.
- Default CPU core chart mode is off.
- Per-core CPU usage ratios are computed from logical processor tick deltas.
- CPU core history is capped to the same chart window as other metrics.
- CPU chart switches to core bars only when enabled and data exists.
- Sampling CPU no longer displays measured `0%`.
- Focused CPU provider, settings, and status store tests pass.
- Full Swift test suite and panel layout smoke pass.

## Metrics

- perceived latency: no new visible wait beyond existing CPU sampling.
- reliability: aggregate CPU display remains available if per-core sampling fails.
- resource use: per-core history remains bounded and sampling stays on the existing refresh path.

## Rollout

- MVP: Preferences toggle, per-core CPU sampling, compact core bars, and `0%` formatting fix.
- later: Larger CPU detail chart if the compact bars prove useful.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/design/stitch.md`
- Stitch `Spill Advanced Feature Settings`
- Stitch `Spill Multi-Widget Panel`
