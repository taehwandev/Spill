# Agent Briefs: Mac Native UI Refinement

## Builder Brief

Goal:

Refine Spill's panel and status color language so the app feels like a native macOS utility instead of a generic bright "AI" interface.

Scope:

- Update centralized status tint mapping.
- Apply the refined palette consistently in panel, footer, action, and menu bar status surfaces.
- Preserve the existing compact tray layout and provider behavior.

Primary files:

- `Sources/Spill/Panel/SpillStatusStyle.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillFooterView.swift`
- `Sources/Spill/Panel/SpillActionViews.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`

Constraints:

- Use macOS semantic colors where possible.
- Do not add a theme system.
- Do not change provider data flow.
- Do not expand the compact panel into a dashboard.

Acceptance:

- Normal, active, warning, and unavailable states remain visually distinct.
- Colors look native in light and dark appearances.
- `swift build`, runtime smoke, and panel layout smoke pass.
