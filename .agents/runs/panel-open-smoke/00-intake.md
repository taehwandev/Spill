# Feature Intake

## Feature ID

`panel-open-smoke`

## Request

Add an automated smoke path that opens the Spill panel during a test launch. Current runtime smoke verifies that the app starts and exits, but it does not exercise the panel presentation path. This feature should make panel-open verification repeatable without relying on manually finding the menu bar trigger.

## User Problem

Spill's most important surface is the compact panel, but recent verification still leaves manual visual checks as a repeated residual risk. If the panel cannot be opened automatically in a smoke run, regressions in panel construction or fallback controls may be missed until manual testing. A panel-open smoke mode gives maintainers a faster confidence check while keeping visual pixel checks as future work.

## Necessity Assessment

Decision: `build`

Reason:

This feature is necessary because the project is now iterating on panel UI and fallback launch paths. It is small, uses the existing app binary, and does not require private APIs or new permissions. It improves verification without adding user-facing complexity.

## Clarifying Questions

No maintainer question blocks this feature. The smoke mode should log panel presentation state only; it should not take screenshots, request Accessibility prompts, or add fake scanner data.

## Target User

- Maintainers verifying panel and fallback work.
- Contributors running local checks before commits.
- Users indirectly, through fewer panel regressions.

## Proposed Product Shape

No normal user-facing product change. When launched with `SPILL_SMOKE_TEST=1` and `SPILL_SMOKE_OPEN_PANEL=1`, the app opens the existing panel, logs a success marker, then exits through the existing smoke shutdown path.

## Constraints

- macOS/public API constraints: use current AppKit panel code only.
- permission constraints: do not request Accessibility during smoke panel opening.
- distribution constraints: no production behavior changes unless smoke environment variables are set.
- performance constraints: keep the smoke run under the existing timeout.

## Non-goals

- No screenshot capture.
- No pixel-level visual regression.
- No fake menu bar item data.
- No second status item.
- No private APIs.
- No Accessibility prompt during smoke panel opening.

## Open Questions

- Whether future CI should run GUI smoke on a hosted macOS runner.
- Whether a later visual smoke should save screenshots when screen capture is available.

## Decision

Status: `accepted`

Reason: The feature closes a practical verification gap with minimal code and no product risk.
