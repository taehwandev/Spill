# Feature Intake

## Feature ID

`token-dashboard-process`

## Request

Split the local token metering dashboard into an independently managed surface so users can open it from the menu bar AI glance, switch dashboard views without turning the compact panel into a large dashboard, and close the dashboard surface without quitting the main Spill menu bar app.

## User Problem

The local token dashboard is useful, but it is visually and behaviorally heavier than the compact Spill panel. Users need a clear dashboard entry point from the menu bar AI area, and they need dashboard close/quit behavior that does not terminate the background menu bar utility. A future process split may also isolate dashboard rendering cost from the always-on menu bar app.

## Necessity Assessment

Assessment:

- Product fit: token metering is part of the AI strip, but detailed analytics should remain a separate surface.
- Ownership: this is Spill-owned macOS app lifecycle and dashboard behavior.
- Compactness: the menu bar panel stays compact; the dashboard remains a detail surface.
- Distribution safety: a real process split affects app packaging, helper launch, shared local store access, and quit semantics.
- Deferral cost: without a scoped PRD, the feature can degrade into a normal window rename rather than true process separation.

Decision: `build`

Reason: The request has a clear user problem, but the process boundary is a larger architecture slice. This run should define the target behavior first, then implement safe precursor UI improvements separately.

## PRD Authoring Gate

If any of the following are unclear, set the decision to `needs-clarification`, ask the maintainer, and stop before writing `01-prd.md`:

- exact dashboard close and quit behavior
- whether the first implementation must be a true helper process or a window lifecycle precursor
- shared local store access constraints
- packaging and notarization impact
- verification strategy for the helper process

## Clarifying Questions

Questions:

- None for PRD authoring. The maintainer explicitly requested process separation if the scope is large, and asked to commit previous work first.

## Target User

AI-heavy local Spill users who keep the menu bar app running while inspecting detailed token usage in a separate dashboard surface.

## Proposed Product Shape

- Menu bar AI glance can be enabled next to the clock.
- Clicking the AI glance opens the local token dashboard directly.
- The compact Spill panel remains the primary tray surface.
- The dashboard process split is specified as a later implementation slice with clear lifecycle, packaging, and store-sharing requirements.

## Constraints

- Use public macOS APIs.
- Do not add cloud sync or auth as part of the local dashboard process split.
- Do not change the safe usage event schema.
- Do not store prompts, commands, files, logs, diffs, source content, or secrets.
- Do not let Command-Q from the dashboard terminate the main menu bar utility.

## Non-goals

- No cloud dashboard implementation.
- No login requirement.
- No private API process management.
- No token event schema expansion.
- No replacement of the compact Spill panel.

## Open Questions

- Whether the helper should be a bundled secondary `.app`, an XPC service plus window host, or a launchable executable target.
- Whether the first release should ship a process-like window lifecycle before a true helper process.

## Decision

Status: `accepted`

Reason: The immediate user-facing behavior can be improved now, while the true process split needs a separate architecture slice.
