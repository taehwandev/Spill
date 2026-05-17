# Deferred PRD Note: Menu Bar Status Mascot

## PRD Authoring Gate

`00-intake.md` has `Decision: defer` and `Clarity: needs-clarification`.

No implementation PRD is authored for this run. The idea is recorded for later
because the visual language, click model, and animation cadence are not yet
resolved, and the current priority is finishing the panel feature-store
refactor.

## Captured Direction

Future work may replace the current droplet-style trigger with a compact mascot
state that still opens the Spill panel. Caffeine and temporary work states could
change that same compact trigger's appearance instead of adding more menu bar
width.

## Deferred Requirements

- Preserve a single compact menu bar trigger.
- Keep Caffeine and status representation glanceable.
- Avoid constant animation.
- Avoid adding a second `NSStatusItem`.
- Resolve direct Caffeine click behavior before implementation.

## Non-goals

- No implementation in this run.
- No asset creation in this run.
- No change to current Caffeine or status behavior in this run.
