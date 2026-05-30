# Spill Review Overlay

Use the shared AgentPlaybook review workflow first:

`${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/workflows/multi-perspective-review.md`

This file adds only Spill-specific review lenses and checks.

## Spill Review Focus

Always include these project-specific questions in non-trivial reviews:

- Product / Scope: Does the change keep Spill a compact macOS control tray
  instead of a dashboard or menu bar recovery promise?
- Native UX: Does the panel/menu bar behavior feel native, compact, theme-aware,
  and usable with limited menu bar space?
- Architecture: Are system providers, UI state, platform APIs, and side effects
  kept behind clear boundaries?
- Reliability / Performance: Are polling cadence, cache behavior, CPU, memory,
  battery, and stale/unavailable states handled quietly?
- Privacy / Permission / Distribution: Does the change avoid private APIs,
  protect signing/notarization/update secrets, and keep network checks opt-in or
  clearly scoped?
- QA / Regression: Were focused build, smoke, panel, status-click, and release
  checks selected according to `.agents/workflows/implementation.md`?

Lead with findings and use the shared severity/output format. For release
reviews, also use `.agents/workflows/release.md` and
`.agents/checklists/release.md`.
