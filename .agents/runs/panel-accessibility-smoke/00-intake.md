# Feature Intake

## Feature ID

`panel-accessibility-smoke`

## Request

Continue the next clear roadmap item after the current verification pass. The
earliest pending roadmap task is M1-T4, which asks for a pixel or
accessibility-tree regression check for compact panel layout. This slice adds an
automated smoke check that can fail when key panel labels disappear from the
accessibility tree.

## User Problem

Panel layout regressions can remove or hide important labels while still passing
build and model tests. A deterministic smoke check gives contributors a cheap
way to catch missing panel landmarks before adding more status and action
content.

## Necessity Assessment

This feature is necessary for the current verification path because M1-T4 is
pending and the compact panel now carries enough content that missing landmarks
should fail automation. Spill owns the smoke command, and the work is limited to
verification rather than additional panel surface area.

Decision: `build`

Reason: The roadmap already identifies M1-T4 as pending, and the existing panel
layout smoke path provides a natural place to add a non-invasive accessibility
check. The feature does not change user-facing behavior, require new
permissions, use private APIs, or expand the compact tray.

## Ambiguity Gate

Use `.agents/workflows/ambiguity-gate.md` before PRD authoring.

Clarity: `clear`

Unknown classification:

- blocker: none
- researchable: exact current smoke coverage, existing panel labels, and script
  wiring are available in the repository.
- assumable: a focused accessibility-tree label check is enough for this slice
  because the roadmap allows detecting missing key labels as an alternative to
  text-overlap detection.
- out-of-scope: screenshot pixel diffing and full visual baseline management.

Resolved inputs:

- maintainer: the latest user request is to continue.
- repo-research: `.agents/tasks/roadmap.yml` marks M1-T4 as pending; the current
  panel smoke script already opens the panel and validates frame/content
  diagnostics.
- assumption: continue means proceed with the next smallest clear roadmap item.

No blocking questions remain.

## PRD Authoring Gate

The request, expected behavior, scope, feasibility, permission impact, and
distribution impact are clear enough to author the PRD.

## Clarifying Questions

Questions:

- none

## Target User

Spill contributors who need automated feedback when compact panel UI landmarks
disappear or fail to render in smoke mode.

## Proposed Product Shape

No end-user UI changes. The panel layout smoke command should also validate a
small accessibility report and fail if required labels are absent.

## Constraints

- macOS/public API constraints: use AppKit/SwiftUI accessibility APIs only.
- permission constraints: do not require Accessibility permission because the app
  can inspect its own panel tree during smoke mode.
- distribution constraints: no private API or signing changes.
- performance constraints: run only in smoke validation mode and keep traversal
  bounded.

## Non-goals

- Pixel-perfect screenshot baselines.
- Full text-overlap detection.
- New panel visuals or layout changes.
- Accessibility permission prompts.

## Open Questions

- none

## Decision

Status: `accepted`

Reason: The slice directly completes a pending roadmap verification task while
staying inside the existing smoke verification architecture.
