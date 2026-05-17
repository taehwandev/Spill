# ARD: Menu Bar Status Mascot

## Architecture Gate

This run is approved for a small implementation slice.

## Constraints To Preserve Later

- Keep ARD-001 intact: use one fixed-width status item and no spacer
  architecture.
- Keep menu bar state presentation behind `StatusItemController` and related
  menu bar rendering helpers.
- Keep trigger animation lightweight, low-cadence, and bounded to the menu bar
  trigger view.
- Keep Caffeine state sourced from `SleepGuardController`.
- Keep status state sourced from existing provider/store models.
- Prefer one composite status item with separate hit regions for the panel
  trigger and Caffeine. A second status item requires an explicit ARD change.
- Keep performance-reactive liquid effects driven by already sampled status
  provider data; do not add high-frequency sampling only for animation.

## Decisions

- Trigger style persistence lives in `SpillSettings` as a raw-value enum.
- The existing `Spill` raw value is retained for compatibility and exposed in
  Preferences as the restored `Drop` symbol option.
- Preferences owns the user-facing trigger icon style control in the top-level
  General & Launch section so it is not hidden behind deeper status controls.
- Preferences renders a live preview using the same menu bar trigger renderer.
- `StatusItemController` builds the trigger segment from the selected style.
- Custom cat/liquid drawing stays behind menu bar rendering helpers; the Drop
  style uses the existing SF Symbol fallback path.
- The trigger uses trigger-specific chip and image metrics so the drawn mascot
  remains legible in the actual menu bar; metric and Caffeine chips keep their
  smaller existing footprint.
- The liquid effect uses existing `SystemStatusStore` snapshots and requires
  CPU, memory, and network snapshots when selected.
- Caffeine keeps the existing adjacent segment hit-test path and remains
  available when the Caffeine clock area item is enabled.
- Caffeine is ordered before the trigger and status metric segments so it sits
  at the far left edge of the composite status item.
- Metric and Caffeine symbols stay with the existing provider/action icon
  choices unless the maintainer explicitly requests an icon change.

## Open Decisions

- Final brand art direction for the cat-like trigger.
- Whether future versions should replace drawn animation with asset-quality
  frames.
- Whether Caffeine should become enabled by default for new users.

## Candidate State Priority

The future implementation should define this explicitly before code changes. A
starting proposal is:

1. Permission/error state.
2. Panel open state.
3. Busy/scanning transient state.
4. Performance load effect.
5. Idle state.

This is only a proposal. The final priority must preserve the panel trigger and
avoid hiding urgent failure states behind decorative motion. Caffeine should
have its own direct action state, so it should not need to compete with the main
trigger state except for shared compact-width constraints.

## Animation Constraints

- Use a low-cadence timer only for animated trigger styles.
- Keep the frame inside a fixed trigger chip so animation frames do not resize
  the status item.
- Keep animation speed and amplitude tied to the sampled aggregate load.
- Avoid widening the status item while frames change.
- Make performance-reactive motion subtle, not a live waveform.
- Keep reduced-motion accessibility behavior in mind before implementation.

## Implementation Boundary

Do not touch panel layout, update behavior, or the web/docs site in this run.
Opening Preferences from the panel should dismiss the panel first so the
settings window is not visually blocked by the popover.
