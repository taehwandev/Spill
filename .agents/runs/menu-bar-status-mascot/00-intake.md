# Feature Intake

## Feature ID

`menu-bar-status-mascot`

## Request

The maintainer wants the menu bar trigger to feel like a compact living status
surface rather than separate unrelated chips. Caffeine and other active states
could be represented by a small animated mascot state, such as a cat tail
movement for awake mode or a running state while work is in progress.

## User Problem

The current leading trigger is functionally correct, but the droplet icon can be
read as a water feature instead of the Spill panel trigger. When Caffeine and
status chips sit beside it, the menu bar item can feel like multiple unrelated
controls instead of one cohesive compact utility.

## Necessity Assessment

- Product fit: yes, because the menu bar trigger is the primary entry point.
- Better owner: Spill, because this is custom menu bar status presentation.
- Compactness: required; the design must preserve minimal menu bar width.
- Platform risk: moderate; animated menu bar content must remain lightweight and
  avoid constant motion.
- Cost of immediate implementation: higher than the current refactor priority
  because it needs visual direction, asset decisions, animation cadence, and
  hit-target behavior.

Decision: `defer`

Reason: The idea is valid and aligned with the product direction, but the
current priority is finishing the panel feature-store refactor before starting a
new menu bar visual system.

## Ambiguity Gate

Clarity: `needs-clarification`

Unknown classification:

- blocker: exact visual language for the mascot, because it changes the primary
  entry point users see in the menu bar.
- blocker: click model, because Caffeine may remain a separate click target or
  move behind a modifier click / panel action.
- blocker: animation cadence, because constant animation can be distracting and
  waste work.
- researchable: current status trigger hit-test implementation.
- assumable: any future implementation must keep a single `NSStatusItem`.
- out-of-scope: implementing this before the active refactor is complete.

## Safe Direction For Later

- Keep one compact `NSStatusItem`; do not add a second menu bar item for
  Caffeine.
- Prefer one trigger-sized mascot icon that changes state over multiple adjacent
  chips.
- Use short, low-frequency animation bursts only for active states.
- Treat Caffeine active as an awake/alert mascot state.
- Treat scanning or refresh work as a temporary running/busy state.
- Keep permission/error state visible through a small badge, tint, or posture
  change instead of expanding menu bar width.

## Non-goals For This Note

- No asset production.
- No SwiftUI/AppKit implementation.
- No new settings.
- No change to the current Caffeine behavior until the refactor is finished.

## Decision

Status: `deferred`

Reason: Documented for future design and implementation after the feature-store
refactor is complete.
