# Feature Intake

## Feature ID

`system-power-provider`

## Request

Add the next real, compact system status signal to Spill after the memory provider. The panel should show useful state instead of decorative placeholders, while staying small enough for a menu bar overflow tool. Power state is a good next candidate because it is available through public macOS APIs and can be represented as a short footer item.

## User Problem

Users want Spill to become a practical compact status surface, not only a place to mirror hidden menu bar icons. Battery percentage, charging state, and external-power state are common glanceable signals. Showing this in the panel validates the provider model without requiring private APIs or a large dashboard.

## Necessity Assessment

Assessment:

- Product fit: this expands Spill from hidden-item actions into verified compact status providers.
- Ownership: macOS already shows battery in the menu bar, but Spill is aggregating compact state next to action access. A small power provider belongs in Spill when the user wants a curated panel.
- Compactness: the MVP is a single icon plus short value in the footer.
- Distribution safety: it uses public IOKit power source APIs and requires no new permissions.
- Deferral cost: the provider model would remain less proven and the panel would continue to rely mainly on menu bar item scanning plus memory status.

Decision: `build`

Reason: Power state is high-signal, compact, public-API compatible, and testable with pure mapping logic.

## Clarifying Questions

Ask the maintainer before implementation if any of these are unclear:

- user intent
- expected behavior
- feature value
- UI scope
- permission or distribution implications

Questions:

- None for this slice. The scope is intentionally limited to read-only power state with no settings UI.

## Target User

Mac users who want a compact, glanceable Spill panel that includes real system state without turning into a large dashboard.

## Proposed Product Shape

The footer shows a small power glyph and either battery percentage, `AC`, or `N/A`. Battery Macs show charge percentage and charging/on-battery state through tint and tooltip. Macs without a battery show `AC` when external power is detected.

## Constraints

- macOS/public API constraints: use IOKit power source APIs only; do not use private frameworks or menu bar manipulation.
- permission constraints: no new permissions.
- distribution constraints: keep the implementation compatible with direct distribution and future notarization.
- performance constraints: read synchronously from a cheap system snapshot only when rendering the compact panel.

## Non-goals

- Do not add a full battery dashboard.
- Do not add notifications, automation, or low-power controls.
- Do not replace macOS Control Center or battery menu behavior.
- Do not add private menu bar APIs.

## Open Questions

- Whether future provider refresh should move to an explicit provider store instead of direct SwiftUI computed reads.

## Decision

Status: `accepted`

Reason: The feature fits the current compact-provider direction and has clear public API boundaries.
