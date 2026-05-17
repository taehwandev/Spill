# PRD: Menu Bar Status Mascot

## PRD Authoring Gate

`00-intake.md` has `Decision: build` and `Clarity: clear`.

## Captured Direction

This slice adds a Preferences-controlled menu bar trigger icon style. The user
can choose a compact droplet symbol, a tail-wagging cat trigger, or a soft
liquid trigger that reacts to sampled system load.

This is specifically the menu bar icon beside the macOS clock/control area. The
goal is to make that tiny icon feel intentional and stateful while preserving
its role as the primary panel trigger.

Caffeine should be visually separated from the panel trigger and directly
clickable. Future implementation should first try to preserve one compact status
surface by using explicit hit regions inside a custom status item.

## Requirements

- Preserve a single compact menu bar trigger.
- Keep Caffeine and status representation glanceable.
- Keep trigger motion lightweight and low-cadence.
- Avoid adding a second `NSStatusItem` unless the architecture decision is
  explicitly reopened.
- Provide a direct Caffeine toggle affordance next to the panel trigger.
- Add the trigger icon style control to Preferences, under the existing clock
  area status settings.
- Keep the trigger compact, but use a trigger-specific icon frame large enough
  to remain legible in the actual macOS menu bar.
- Prefer stateful mascot variants over adjacent text-heavy chips.
- Keep the user-selectable styles to Drop, animated Cat, and animated Liquid
  treatments.
- Let the droplet/liquid layer react subtly to overall PC performance, using
  CPU, memory, and network activity from existing samples.
- Keep warning/error states visible through compact tint, badge, or posture
  changes.
- Show the restored droplet symbol as the `Drop` trigger style choice.
- Show a live Preferences preview for the selected trigger style.

## Candidate Mascot States

- Idle: default cat trigger state.
- Panel open: active trigger state.
- Caffeine active: adjacent direct action active state.
- Busy/scanning: short running state.
- Performance load: soft liquid ripple, pulse, or tension state.
- Warning/error: compact badge/tint/posture state.

## Scenarios

### Trigger Icon Setting

Given the user opens Preferences
When they view General & Launch
Then they can choose `Drop`, `Cat`, or `Liquid` as the menu bar trigger icon.

Given the selected trigger icon style is visible in Preferences
When animation is enabled
Then Preferences shows a small live preview of the selected trigger motion.

### Panel Settings Button

Given the Spill panel is open
When the user clicks the Settings button
Then the panel closes and Preferences opens in front.

### Caffeine Direct Action

Given the Caffeine clock area item is enabled
When the user clicks the Caffeine segment
Then Spill toggles Caffeine without opening the panel.

Given CPU or Memory status items are also enabled
When Caffeine is visible in the clock area item
Then Caffeine appears at the far left edge before the panel trigger and status
segments.

### Panel Trigger

Given the user clicks the panel trigger segment
When the click is not inside the Caffeine segment
Then Spill opens or closes the panel.

### Liquid Performance Effect

Given `Liquid` is selected
When sampled CPU, memory, or network activity rises
Then the trigger uses a stronger animated liquid state without adding an extra
status item or extra high-frequency sampling.

Given `Cat` is selected
When Spill renders the menu bar trigger
Then the trigger uses compact motion such as tail movement or small bobbing
inside the same hit target.

Given `Drop` is selected
When Spill renders the menu bar trigger
Then the trigger uses the compact droplet symbol without custom animation.

Given `Drop`, `Cat`, or `Liquid` is selected
When Spill renders the actual menu bar status item
Then the trigger icon is larger than ordinary metric-only symbols while keeping
the composite status item compact.

## Non-goals

- No bitmap asset production in this run.
- No large mascot animation system in this run.
- No second status item in this run.
- No update-related behavior in this run.
