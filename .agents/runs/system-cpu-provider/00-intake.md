# Feature Intake

## Feature ID

`system-cpu-provider`

## Request

Continue building the system status strip after memory, power, and provider caching. Add the CPU provider foundation without adding visible UI placement yet. The provider should expose deterministic status mapping and be ready for a later panel integration decision.

## User Problem

CPU usage is one of the core compact system signals in the roadmap. Adding the provider now builds the data layer while avoiding premature UI decisions about where another metric should appear in the already compact panel.

## Necessity Assessment

Assessment:

- Product fit: CPU is a planned system strip signal.
- Ownership: macOS has Activity Monitor, but Spill needs a compact provider value for its tray.
- Compactness: this slice adds data only and does not add UI.
- Distribution safety: use public Mach host CPU statistics; no private APIs and no new permissions.
- Deferral cost: future panel work would lack a tested CPU status model.

Decision: `build`

Reason: The provider foundation is clear, testable, and does not make unresolved UI choices.

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

- None for this slice. Panel placement is explicitly out of scope and should be confirmed later.

## Target User

Maintainers adding system status providers and future users who want compact CPU state in Spill.

## Proposed Product Shape

No visible product change in this slice. The app gains a tested CPU status provider that can later be connected to `SystemStatusStore` and the panel after UI placement is approved.

## Constraints

- macOS/public API constraints: use public Mach host CPU tick APIs only.
- permission constraints: no new permissions.
- distribution constraints: keep notarization and direct distribution path unchanged.
- performance constraints: do not block SwiftUI rendering; the provider should support sampled delta calculations.

## Non-goals

- Do not render CPU in the panel yet.
- Do not add polling or refresh cadence changes.
- Do not add charts or process-level CPU lists.
- Do not add private APIs.

## Open Questions

- Where CPU should appear in the compact panel.
- Whether CPU should share one row with memory or be hidden behind a system detail view.

## Decision

Status: `accepted`

Reason: CPU provider foundation is useful and does not depend on unresolved UI scope.
