# Feature Intake

## Feature ID

`panel-feature-store`

## Request

The maintainer approved a lightweight unidirectional Feature Store architecture
for Spill. The first implementation slice should start that migration without
destabilizing the existing panel behavior. Verification is the priority because
the current menu bar, panel, status, AI, caffeine, and window-action behavior
must remain intact.

## User Problem

Panel behavior is currently derived directly inside `SpillBarView` from several
observable objects. That makes future changes riskier because UI rendering,
state derivation, and feature policy are mixed. The project needs a stable
architecture target before adding more features.

## Necessity Assessment

- Current product direction: required by ARD-008 as the first architecture
  migration slice.
- Ownership: this must be solved inside Spill because it is source
  architecture, not user configuration or a macOS-provided feature.
- Compact tray fit: behavior-preserving and does not add panel surface area.
- API and distribution impact: no private APIs, no new permissions, and no
  signing or packaging changes.
- Cost of deferral: the panel will keep accumulating direct dependencies and
  future UI/provider changes will be harder to verify.

Decision: `build`

Reason:

This is the first low-risk migration step required by ARD-008 and can be
validated with unit tests, build checks, and existing runtime smoke scripts.

## Ambiguity Gate

Use `.agents/workflows/ambiguity-gate.md` before PRD authoring.

Clarity: `clear`

Unknown classification:

- blocker: none
- researchable: current `SpillBarView`, panel controller, provider models,
  PRD, and ARD were inspected before authoring.
- assumable: the first slice should be behavior-preserving and start with
  `PanelState`, `PanelAction`, and `PanelStore` because ARD-008 lists that as
  the migration order.
- out-of-scope: visual redesign, new panel sections, new providers, and
  distribution changes.

Resolved inputs:

- maintainer: use lightweight Feature Store architecture and prioritize
  verification.
- repo-research: `SpillBarView` currently derives display items, pinned items,
  action items, visible status modules, and panel state directly from stores.
- assumption: this slice should not rename the user-facing "Spill Flow" header
  or change any panel layout.

## PRD Authoring Gate

Decision is `build`, clarity is `clear`, and there are no blocking questions.

## Clarifying Questions

Questions:

- None.

## Target User

Maintainers and contributors who need to change Spill panel behavior without
regressing the compact tray.

## Proposed Product Shape

Users should see no intentional UI behavior change. Internally, panel
presentation state should move behind a feature store so SwiftUI can render a
single derived state model.

## Constraints

- macOS/public API constraints: keep public API usage only.
- permission constraints: do not change Accessibility permission behavior.
- distribution constraints: no bundle, signing, notarization, or installer
  changes.
- performance constraints: state derivation must remain cheap and synchronous.

## Non-goals

- Redesign the panel.
- Move all panel actions into the store in one pass.
- Replace existing AppKit bridge controllers.
- Introduce Redux, TCA, or a global reducer dependency.
- Change provider output models.

## Open Questions

- None for this slice.

## Decision

Status: `accepted`

Reason:

The slice is narrow, reversible, aligned with ARD-008, and verifiable.
