# Feature Intake

## Feature ID

`visual-panel-verification`

## Request

Continue the next roadmap task after provider caching. The next clear item is visual panel verification so the project can catch compact layout regressions before adding CPU, AI, and window actions. The first slice should be an automated panel layout smoke check, not a subjective redesign.

## User Problem

The app already has runtime and panel-open smoke checks, but they only prove the panel can open. They do not verify that the panel frame is compact, on-screen, and sized as expected. Without this gate, future provider or UI work can silently make the panel too large or malformed.

## Necessity Assessment

Assessment:

- Product fit: required before adding more visible panel content.
- Ownership: this is Spill verification infrastructure.
- Compactness: it enforces the compact tray size rather than adding UI.
- Distribution safety: it uses smoke mode and public AppKit window geometry only.
- Deferral cost: UI regressions remain manual and easy to miss.

Decision: `build`

Reason: The intent is clear, the implementation is internal verification, and no product behavior choice is ambiguous.

## PRD Authoring Gate

If any of the following are unclear, set the decision to `needs-clarification`, ask the maintainer, and stop before writing `01-prd.md`:

- user intent
- expected behavior
- feature value
- UI scope
- feasibility
- permission impact
- distribution impact

Only write the detailed PRD after the maintainer answers and this intake is updated with `Decision: build`.

## Clarifying Questions

Ask the maintainer before PRD authoring if any of these are unclear:

- user intent
- expected behavior
- feature value
- UI scope
- feasibility
- permission or distribution implications

Questions:

- None. This slice checks existing panel geometry and does not define new UI behavior.

## Target User

Maintainers and contributors who need a repeatable way to verify compact panel layout after UI changes.

## Proposed Product Shape

No user-facing change. A new workflow command launches the app in smoke mode, opens the panel, asks the app to report layout geometry, and fails if compact layout checks do not pass.

## Constraints

- macOS/public API constraints: use public AppKit window/frame APIs only.
- permission constraints: no new permissions.
- distribution constraints: no production behavior change.
- performance constraints: run only in explicit smoke mode.

## Non-goals

- No screenshot pixel comparison in this first slice.
- No redesign of the panel.
- No new provider or UI content.
- No private APIs.

## Open Questions

- Whether a future screenshot-based test can be made reliable without Screen Recording permission.

## Decision

Status: `accepted`

Reason: Automated layout smoke verification is a small, clear, necessary follow-up to the current panel work.
