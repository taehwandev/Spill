# Feature Intake

## Feature ID

`panel-glass-footer-contrast`

## Request

The maintainer clarified that the dashboard's own footer/menu bar should stay visually clean after its background is removed, but its text and status information must remain readable over light and dark glass surfaces. White backgrounds currently make some values disappear, while darker cmux-like tones are acceptable. After the first contrast pass, the maintainer also called out blue accents as weak on bright glass in both the dashboard and the clock-adjacent menu bar.

## User Problem

Transparent glass UI can sit over changing light and dark surfaces. If footer text and status colors are fixed or too muted, important values such as time, count, power, or Sleep Guard state become unreadable.

## Necessity Assessment

- Product direction: this supports the compact control tray without reintroducing heavy containers.
- Ownership: Spill owns the panel footer SwiftUI composition.
- Scope: this is limited to footer/menu-bar contrast and active accent color; it does not change providers or settings.
- API and permission impact: no private APIs, no new permissions, and no distribution risk.
- Cost of deferral: the clean transparent footer remains unreliable on bright backgrounds.

Decision: `build`

Reason: The request is a focused UI legibility fix for an existing compact panel surface.

## Ambiguity Gate

Use `.agents/workflows/ambiguity-gate.md` before PRD authoring.

Clarity: `clear`

Unknown classification:

- blocker: none.
- researchable: the dashboard menu/status bar implementation; resolved as `SpillFooterView`.
- assumable: keep the transparent footer, improve foreground contrast, and replace weak active-blue accents with brighter teal accents.
- out-of-scope: sampling arbitrary screen pixels, adding preferences, or redesigning the whole panel.

Resolved inputs:

- maintainer: the dashboard footer/menu bar should adapt to light and dark Liquid Glass backgrounds; blue accents should not be used where they disappear on bright glass.
- repo-research: `SpillFooterView` renders AX, scan, Caffeine, power, count, and time in a compact footer strip; values currently inherit status tint such as mint or secondary.
- assumption: values should be the highest-contrast foreground, while status color should primarily live on icons.

## PRD Authoring Gate

The goal, UI scope, implementation feasibility, permission impact, and distribution impact are clear. No maintainer clarification is required.

## Clarifying Questions

Questions:

- none.

## Target User

Users who open the Spill panel over different desktop, window, and material backgrounds.

## Proposed Product Shape

The panel footer remains transparent and compact. Icons keep status color, labels remain secondary, and values render as adaptive primary text with subtle glass-readable shadowing. Active status accents use teal instead of blue in the panel and clock-adjacent status item.

## Constraints

- macOS/public API constraints: use SwiftUI semantic colors and existing panel material.
- permission constraints: none.
- distribution constraints: no private APIs.
- performance constraints: no screen sampling, timers, or provider changes.

## Non-goals

- Add a visible footer background.
- Redesign status rows or action grids.
- Change provider state, refresh cadence, or persistence.
- Add a user preference.

## Open Questions

- none.

## Decision

Status: `accepted`

Reason: Small, reversible contrast correction for the transparent panel footer.
