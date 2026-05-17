# Feature Intake

## Feature ID

`menu-bar-status-mascot`

## Request

The maintainer wants the menu bar trigger to feel like a compact living status
surface rather than separate unrelated chips. Caffeine and other active states
could be represented by a small animated mascot state, such as a cat tail
movement for awake mode or a running state while work is in progress.

The maintainer clarified that this note is about the clock-adjacent menu bar
icon design, not the update mechanism. The target surface is the tiny visible
Spill item near the macOS clock/control area.

The maintainer later clarified the desired direction:

- The panel trigger should prefer a cat-like shape with visible tail motion.
- Caffeine should be visually separated and directly clickable next to the
  trigger.
- The built-in droplet symbol should be restored as a `Drop` trigger style
  choice.
- The droplet/liquid motif should feel soft and malleable, and may react to
  overall PC performance rather than representing a water feature.

## User Problem

The current leading trigger is functionally correct, but the droplet icon can be
read as a water feature instead of the Spill panel trigger. When Caffeine and
status chips sit beside it, the menu bar item can feel like multiple unrelated
controls instead of one cohesive compact utility. The refined direction should
make the trigger feel intentional while giving Caffeine a direct control affordance.

## Necessity Assessment

- Product fit: yes, because the menu bar trigger is the primary entry point.
- Better owner: Spill, because this is custom menu bar status presentation.
- Compactness: required; the design must preserve minimal menu bar width.
- Platform risk: moderate; animated menu bar content must remain lightweight and
  low-cadence.
- Cost of immediate implementation: higher than the current refactor priority
  because it needs visual direction, asset decisions, animation cadence, and
  hit-target behavior.

Decision: `build`

Reason: The maintainer approved starting implementation and clarified that the
icon should be changed from Preferences. The first slice is small enough to keep
the compact menu bar surface intact: add a menu bar trigger icon style setting,
preserve the existing Caffeine direct click behavior, and add a lightweight
liquid performance effect using already sampled status provider data.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none for this slice.
- researchable: current status trigger hit-test implementation.
- assumable: cat and liquid are first-pass compact styles, not final brand art.
- assumable: the liquid effect can aggregate CPU, memory, and network by
  default using existing snapshots.
- out-of-scope: bitmap asset production or changing
  ARD-001 to multiple status items.

Resolved inputs:

- maintainer: icon style should be changed from Settings / Preferences.
- maintainer: Caffeine should remain visually separated and directly clickable.
- maintainer: restore the droplet symbol as a trigger choice.
- maintainer: Preferences should include a live preview for the trigger icon.
- repo-research: `StatusItemController` already uses one `NSStatusItem` and
  routes Caffeine segment clicks separately when the Caffeine menu bar item is
  enabled.
- assumption: keep the existing `Spill` raw value for compatibility, but expose
  it to users as `Drop` because the maintainer asked to restore the droplet
  symbol.
- assumption: make `Drop` the default because the latest maintainer direction
  specifically asks to restore the droplet symbol.

## Implementation Direction

- Keep one compact status surface. Prefer one custom `NSStatusItem` with clear
  internal hit regions for the panel trigger and Caffeine before considering a
  second status item.
- Use the panel trigger as the primary identity surface, and let Caffeine be a
  small adjacent direct action rather than a hidden secondary state.
- Provide the restored `Drop` symbol as the compact static trigger option.
- Keep the cat-like trigger with visible tail movement available at menu bar
  size.
- Treat the droplet/liquid motif as a soft performance-reactive material: calm
  when the system is quiet, subtly rippled or tense when CPU, memory, battery,
  or network activity indicates load.
- Use low-frequency animation inside the trigger chip without changing its
  width.
- Treat Caffeine active as the state of the adjacent Caffeine action, with an
  optional awake/alert relationship to the mascot only when space allows.
- Treat scanning or refresh work as a temporary running/busy state.
- Keep permission/error state visible through a small badge, tint, or posture
  change instead of expanding menu bar width.
- Keep the default footprint close to the current trigger width. Expanded status
  labels remain optional user settings, not the mascot default.

## Candidate State Set

Document these as starting candidates, not final art direction:

- Idle: compact neutral cat/mascot posture, panel trigger role is clear.
- Panel open: active posture or filled variant.
- Caffeine active: adjacent direct action appears active; mascot may optionally
  show an awake hint, such as alert ears, when it does not confuse the click
  target.
- Busy/scanning: short running or stepping burst.
- Performance load: soft droplet ripple, viscosity, or pulse intensity derived
  from overall system activity.
- Warning/error: tiny badge, tint, or posture shift without adding text.

## Interaction Direction

- Left click on the main mascot area opens or closes the Spill panel.
- A visually separated Caffeine area immediately toggles Caffeine.
- Right click or Control-click keeps the existing menu.
- Direct Caffeine toggling should be available without opening the panel.
- Preferences shows a live preview of the selected animated trigger style.
- The preferred implementation is a composite menu bar view with explicit
  hit regions inside one `NSStatusItem`; using multiple status items would need
  an explicit architecture decision because it weakens the single-trigger rule.

## Non-goals For This Note

- No asset production.
- No large panel redesign.
- No second status item.
- No external provider calls or private API usage.
- No high-frequency animation or extra sampling loop in the menu bar.

## Decision

Status: `accepted`

Reason: Implement the first settings-controlled icon style slice while preserving
the compact single-status-item architecture.
