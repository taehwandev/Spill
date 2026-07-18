# App Foundation PRD

## Document Contract

- Status: active
- Audience: product, design, engineering, QA, and release maintainers
- Purpose: define first-run, onboarding, permission, and app-foundation behavior
- Source of truth: this document owns app-foundation product requirements
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md)

## Scope

This document owns the first-run and onboarding requirements previously kept in
the root PRD. Preferences that belong to another product domain remain owned by
that domain PRD.

## First-Run And Onboarding

Requirements:

- First launch opens the compact panel or a lightweight welcome state that
  explains the tray trigger, compact panel, and local-first privacy model.
- The compact panel and any local dashboard entry point must have an onboarding
  preview path. The preview should make the app behave as if optional local
  integrations are not installed, without deleting or hiding real user data.
- Onboarding previews must use a deterministic app-owned fixture or preview
  data source, not a destructive reset, not a real token event write, and not a
  forced empty rendering of the production store.
- Users can continue without account creation.
- Accessibility permission is requested only when the user enables or invokes a
  feature that needs it, such as window actions or best-effort menu bar item
  scanning.
- Token metering setup is offered as an optional setup card in Preferences and
  the local token dashboard. It should explain what is counted, what never
  leaves the device, and why exact runtime usage metadata is required.
- The setup card must separate a direct basic metering `Install` or `Reinstall`
  action from a `Copy Workflow Setup` alternative. The direct action installs
  exact token collection without work-type or stage classification. The copied
  workflow setup is for users who want safe reusable `task_type` and `stage`
  grouping and must be run from the directory that owns their workflow.
- The direct action runs the bundled installer only after the user clicks it,
  reports success or failure, preserves existing workflow integrations, and
  never treats copying instructions as proof that metering is installed.
- The global setup prompt and one-step installer should be available, but the UI
  must not imply that a prompt alone can measure token usage.
- The public one-step installer owns one canonical runtime instruction at
  `~/.spill/runtime-instruction.md`. It must add only a small managed discovery
  bridge to the active user instruction file for Codex, Claude Code, and
  Antigravity/AGY, preserve unrelated instructions, and avoid asking users to
  maintain three full prompt copies.
- The in-app basic installer must not add the shared runtime instruction or its
  discovery bridges. Existing bridges remain untouched when basic metering is
  installed or repaired.
- Web dashboard connection is optional and clearly separate from local metering.

Acceptance:

- A new user can understand the tray and open Preferences without granting
  Accessibility permission.
- The general dashboard/panel entry and the local token dashboard can both be
  tested in onboarding mode while preserving the real local stores.
- Token metering setup is discoverable without being mandatory.
- Permission prompts are tied to the feature that requires them.
- The onboarding copy does not imply cloud upload, prompt collection, or
  realtime sync.

## Open Coverage Decisions

The current product exposes additional app-foundation behavior that was not
normatively defined by the former root PRD. A follow-up product decision must
either accept, revise, defer, or remove each behavior:

- Launch at Login.
- Application language selection and supported locales.
- Appearance theme selection.
- Product-wide keyboard navigation, reduced-motion, and accessibility rules.

## Verification

- Verify first-run and preview states do not mutate production stores.
- Verify permission prompts occur only from the feature that requires them.
- Verify any accepted setting defines persistence, default, migration,
  propagation, affected surfaces, and update latency.
