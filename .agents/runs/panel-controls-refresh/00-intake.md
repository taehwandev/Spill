# Feature Intake

## Feature ID

`panel-controls-refresh`

## Request

The maintainer reported that menu bar CPU and memory values did not visibly update after closing panel details. They also asked for Sleep Guard time configuration, a clear way to quit from the panel, and documentation updates. The latest maintainer feedback adds a larger panel metrics correction: remove the low-value GPU card, add storage instead, draw panel graphs, make the panel status area read as three clear metric rows, and fix the Settings icon removal behavior.

## User Problem

Users cannot trust glanceable metrics if they appear frozen, and compact footer icons are not enough when controls need to be understood quickly. The current GPU card does not provide useful value, while storage is a commonly needed local system signal. Settings must reliably remove configured icons because broken removal makes the app feel uncontrollable.

## Necessity Assessment

- Product fit: This directly supports the compact control tray promise.
- Ownership: Spill owns this panel, settings, and menu bar status behavior.
- Scope fit: The slice stays compact if scoped to three primary metric rows and small inline sparklines.
- Platform risk: No private APIs, fragile system behavior, or new permission burden is required.
- Cost of not building: The panel remains confusing, status values appear stale, and Settings removal remains unreliable.

Decision: `build`

Reason: The work fixes visible trust, control discoverability, useful metric coverage, and settings reliability using existing public APIs and local settings.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none
- researchable: existing refresh cadence, Sleep Guard settings model, footer layout, Settings icon removal code path, storage APIs
- assumable: "time" means Sleep Guard default duration because the request followed Sleep Guard status feedback; "3 lines" means three primary metric rows in the panel status area
- out-of-scope: arbitrary custom minute entry, a full monitoring dashboard, network throughput parity, and a full iStat clone

Resolved inputs:

- maintainer: menu bar status values must update after panel details close; Sleep Guard time should be configurable; panel should include Quit; GPU should be removed; storage should replace it; panel should include graphs; Settings icon removal must work
- repo-research: `refreshInterval` was shared with menu bar scanning and status metrics; Sleep Guard durations already exist as `SleepGuardDuration`; system providers already follow small plain-model patterns
- assumption: fixed duration choices remain sufficient for this slice; storage can use local volume capacity from public Foundation APIs

## PRD Authoring Gate

The request is clear enough to proceed. No permission, privacy, network, or distribution change is required.

## Clarifying Questions

Questions:

- None.

## Target User

Users who rely on Spill as a glanceable menu bar and compact panel utility.

## Proposed Product Shape

Preferences exposes a Sleep Guard default duration picker. The panel footer uses that duration for a quick start action and includes a visible Quit control. Menu bar CPU and memory status refresh independently from slower menu bar item scanning. The panel status section becomes three primary metric rows for CPU, Memory, and Storage, each with useful values and a small sparkline. GPU is removed from the primary panel status surface.

## Constraints

- macOS/public API constraints: stay on AppKit, SwiftUI, IOKit power assertions, Foundation volume APIs, and public status item APIs.
- permission constraints: no new permission prompts.
- distribution constraints: no private frameworks.
- performance constraints: metric refresh must be lightweight, graphs must be bounded in memory, and AX scan frequency must not increase.

## Non-goals

- Arbitrary custom Sleep Guard minute entry.
- Increasing AX menu bar scan frequency.
- Full disk I/O throughput monitoring.
- Full historical charting or dashboard layout.
- Replacing dedicated GPU or storage monitoring apps.

## Open Questions

- None for this slice.

## Decision

Status: `accepted`

Reason: Small, reversible, and aligned with compact tray usability.
