# System Status PRD

## Document Contract

- Status: active
- Audience: product, engineering, and QA
- Purpose: define local system metrics, presentation, and resource constraints
- Source of truth: this document owns system-status product requirements
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md),
  [Menu Bar Surface](menu-bar-surface.md), [Compact Panel](compact-panel.md)

## Current Metrics

- CPU usage and per-core activity, with one-minute load and system facts when available.
- Memory usage and available capacity, with qualitative pressure when available.
- Primary storage used and available capacity.
- Network throughput and preferred connection type when available.
- GPU utilization and core count when the driver supplies them; device information otherwise.
- Battery percent/state in the panel footer.

## Requirements

- Read-only pills.
- Compact labels.
- Refresh interval configurable later; use a conservative default.
- On Apple Silicon, show one-minute CPU load, processor count, system uptime,
  qualitative thermal state, and qualitative memory pressure when available.
  Do not present load or memory pressure as a CPU or memory usage percentage.
- Show the preferred network path type when macOS supplies it.
- Offer best-effort GPU utilization and core count. Show utilization only when
  the driver supplies a finite in-range percentage; otherwise retain device
  information without claiming it is GPU usage.
- Omit numeric temperatures and fan RPM until a distributable, model-verified
  sensor reader can identify the value and its unavailable state.
- CPU usage defaults to a multicore/system-wide interpretation. Preferences
  should not expose a separate option to choose among multiple CPU calculation
  modes unless a later PRD defines a real user workflow for that distinction.
- Avoid high CPU overhead.
- Closing Preferences releases its hosted UI and window-scoped preview work;
  hidden configuration surfaces must not keep animations or layout passes alive.

## Acceptance

- Metrics update without blocking UI.
- Missing metrics show a quiet unavailable state.
- Additional values reuse the existing refresh cadence without elevated
  permission, fan control, or another periodic sampler.
- GPU status can be disabled in Preferences. Existing installations receive
  its new default once and keep any later explicit opt-out.
- Redundant CPU mode settings are removed from Preferences and no longer affect
  status display.
- Reopening Preferences recreates its UI normally after the previous window was
  closed and released.

## Verification

- Verify metrics refresh without blocking the main UI.
- Verify hidden or unavailable metrics do not keep unnecessary polling alive.
- Verify supported GPU readings, missing-property fallback, the GPU default
  migration and opt-out, panel display, and unaffected AI surfaces.
- Verify the accepted metric set matches panel, menu bar, Preferences, tests,
  and roadmap documentation.
