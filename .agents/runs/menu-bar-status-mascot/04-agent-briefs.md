# Agent Briefs: Menu Bar Status Mascot

## Status

Implemented as a small settings-controlled menu bar trigger style slice.

## Future Builder Brief

Research `StatusItemController`, `MenuBarStatusContentView`, and
`SleepGuardController`. Propose the smallest implementation that keeps one
`NSStatusItem` if feasible, preserves the panel trigger, and gives Caffeine a
visually separated direct click affordance without expanding menu bar width
more than necessary.

Treat the target surface as the clock-adjacent Spill icon, not the update UI or
the compact panel. Start from a state table for idle, panel-open, Caffeine,
busy/scanning, and warning/error before drawing or implementing assets.

Explore a cat-like panel trigger with visible tail motion. The liquid treatment
may react to aggregate PC performance, but it must use existing provider
snapshots and thresholded visual states instead of continuous sampling.

Implemented write scope:

- `Sources/Spill/MenuBar`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Sources/Spill/Preferences/StatusModulesPreferencesSection.swift`
- `Sources/Spill/App/AppDelegate.swift`
- focused tests under `Tests/SpillTests`

## Future Verifier Brief

Verify menu bar hit targets, status item width, Caffeine state representation,
right-click menu behavior, and smoke checks. Include a manual check for whether
motion feels distracting.

Also verify that animation does not resize the status item and that overlapping
states follow the documented priority.

Verify that the panel trigger and Caffeine affordance are independently
clickable, visually separable, and still read as one compact Spill-owned menu
bar surface.
