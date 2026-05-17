# Agent Briefs: Menu Bar Status Mascot

## Status

Deferred. Do not implement until the active panel feature-store refactor is
complete and the open visual and interaction decisions are resolved.

## Future Builder Brief

Research `StatusItemController`, `MenuBarStatusContentView`, and
`SleepGuardController`. Propose the smallest implementation that keeps one
`NSStatusItem`, preserves the panel trigger, and represents Caffeine/status
without expanding menu bar width.

## Future Verifier Brief

Verify menu bar hit targets, status item width, Caffeine state representation,
right-click menu behavior, and smoke checks. Include a manual check for whether
motion feels distracting.
