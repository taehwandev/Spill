# Spill Product Requirements

## Document Contract

- Status: active
- Audience: product, design, engineering, QA, privacy, and release maintainers
- Purpose: define Spill's product direction and route readers to canonical domain PRDs
- Source of truth: this page owns product-wide direction; linked domain PRDs own detailed requirements
- Related: [Spill ARD](ard.md), [Implementation roadmap](../tasks/roadmap.yml)

## Summary

Spill is a compact macOS control tray for people whose menu bar is crowded,
especially on notched MacBooks.

It does not try to force macOS to reveal or rearrange every hidden menu bar
icon. Instead, Spill provides a small, fast panel that combines:

- pinned menu bar and app actions;
- system status;
- AI/tooling status, including local token usage;
- quick window actions;
- optional local dashboard and web dashboard surfaces for deeper token metering.

The product should feel closer to a tiny native utility tray than a dashboard.
Detailed views are allowed, but they remain secondary entry points from the
compact tray, Preferences, or web portal.

## Problem

macOS menu bar space is limited. On notched MacBooks, menu bar extras can
disappear behind the notch or be hidden by the system. Apple does not provide a
public API to enumerate, clone, reorder, resize, or reveal every third-party
menu bar extra.

AI-heavy users also run multiple local agents and API tools. They need a local,
privacy-preserving way to understand usage without sending prompts, commands,
source files, logs, or repository context to a server.

Users need quick access to both actionable shortcuts and status indicators such
as memory, CPU, battery, network, AI agent state, and local token usage. Existing
solutions often rely on fragile spacer tricks, private APIs, large dashboards,
or separate apps for each small utility.

## Product Positioning

Spill is:

- a small Mac control tray;
- a menu bar action shelf;
- a glanceable system and AI status strip;
- a light window-action launcher;
- a local-first AI token usage meter;
- an optional encrypted aggregate backup and web dashboard.

Spill is not:

- a full iStat Menus clone;
- a full Rectangle clone;
- a full Raycast clone;
- a guaranteed menu bar icon restoration tool;
- a private API menu bar hack;
- a cloud-first analytics SDK;
- a prompt, command, repository, transcript, or source-code collector.

## Target Users

- MacBook users with a notch.
- Developers and AI-heavy users.
- Users with crowded menu bars.
- Users who run tools like Rectangle, iStat Menus, Hidden Bar, Ice, Raycast,
  Hammerspoon, Ollama, Codex, Claude Code, Antigravity/AGY, or local agents.
- Users who prefer a small native utility over a large always-open dashboard.
- Users who want optional web aggregate statistics without giving Spill access
  to private work content.

## Core Principles

1. **Always visible trigger**
   Spill keeps one small menu bar trigger. No giant spacer.

2. **Glance first**
   The panel should answer "what is happening?" in one second.

3. **Actionable by default**
   Items should be clickable, not decorative.

4. **Best-effort is honest**
   If a third-party menu bar action cannot be pressed, show a fallback.

5. **Local first**
   Core token metering and tray behavior work without login, cloud upload,
   telemetry, or a web dashboard.

6. **Small surface area**
   The panel is compact. Deep configuration belongs in Preferences. Detailed
   token metering belongs in the local dashboard helper or web portal.

7. **Open-source distributable**
   Avoid private APIs and fragile system hooks.

8. **Content-free metering**
   Token usage features may count safe numeric and categorical data, but must
   not collect prompts, responses, commands, file paths, repo names, branch
   names, terminal output, logs, diffs, source content, environment values, or
   secrets.

## Canonical Product Requirements

| Domain | Canonical PRD | Ownership |
| --- | --- | --- |
| App foundation | [App Foundation](prd/app-foundation.md) | First-run, onboarding, permissions, and app-wide Preferences foundations |
| Menu bar | [Menu Bar Surface](prd/menu-bar-surface.md) | Spill trigger, status items, glance modes, and status menu |
| Top glance | [Top Glance Surface](prd/top-glance-surface.md) | Always-visible grouped top bar, module visibility, placement, and dashboard entry |
| Compact panel | [Compact Panel](prd/compact-panel.md) | Panel composition, size, placement, and panel-level UX |
| System status | [System Status](prd/system-status.md) | CPU, memory, battery, network, storage decisions, and resource constraints |
| AI status | [AI Status](prd/ai-status.md) | Local AI process/config state and official service status |
| Actions | [Quick Actions And Window Management](prd/quick-actions-and-window-management.md) | Pinned/detected actions, window movement, and action permissions |
| Local token collection | [Local Token Collection](prd/token-metering/local-collection.md) | Safe event collection, setup, normalization, and accuracy |
| Local token dashboard | [Token Metering Dashboard](prd/token-metering/dashboard.md) | Dashboard UX, Work Items, filters, cost display, and input scope |
| Token history | [Token History Import](prd/token-metering/history-import.md) | Explicit historical reconciliation, cursors, and event identity |
| Usage limits | [AI Usage Limits](prd/ai-usage-limits.md) | Remaining rate-limit percentages, credits, reset countdowns, and estimation policy |
| Private upload | [Private Usage Upload](prd/token-metering/private-usage-upload.md) | Native encrypted aggregate upload and retry behavior |
| Web boundary | [Web Companion Contract](prd/token-metering/web-companion-contract.md) | Cross-repository connection, role, authorization, and privacy contracts |
| Privacy and diagnostics | [Privacy And Observability](prd/privacy-and-observability.md) | Product telemetry, diagnostics, and data lifecycle decisions |
| Distribution | [Distribution And Updates](prd/distribution-and-updates.md) | Update UX, compatibility, signing, notarization, and distribution |

## Source-Of-Truth Rules

- This index owns only product-wide direction and cross-domain invariants.
- Detailed normative requirements live in exactly one canonical domain PRD.
- The [ARD](ard.md) owns architecture, data flow, module boundaries, and
  implementation decisions rather than user-facing product requirements.
- Files under `.agents/runs/` are execution records and feature-slice evidence.
  They may link to canonical PRDs but do not replace them as the current source
  of truth.
- README files describe current usage and distribution. They do not introduce
  product policy that is absent from canonical PRDs.
- Hosted web implementation details remain in the private Spill-web repository;
  this public repository owns only the shared app/web contract.

## Non-Goals

- Recover every hidden menu bar extra.
- Copy every third-party badge/count from the menu bar.
- Read private state from other apps.
- Use private frameworks.
- Create a huge monitoring dashboard in the compact panel.
- Replace dedicated power-user tools in MVP.
- Make cloud account connection mandatory.
- Upload raw token events or private work content.
- Use telemetry as a usage metering path.

## Future Scope

- Plugin/provider system.
- Service integrations:
  - Slack mentions
  - GitHub notifications
  - Calendar next event
  - Gmail unread count
- Custom user scripts.
- Homebrew Cask.
- Optional ScreenCaptureKit experiments for user-approved visual previews.
- Paid multi-device or higher-frequency encrypted aggregate upload.
- Account key recovery for private usage upload.
- Signed Sparkle appcast updates after Developer ID release infrastructure is ready.

## Open Product Coverage Decisions

The split preserved former root-PRD commitments and made known documentation
gaps explicit. These items are not accepted requirements until product review
resolves them in the owning domain PRD:

- The canonical system metric set, including Storage versus Battery/Network.
- The expanded window action set, global shortcuts, and Sleep Guard behavior.
- Launch at Login, supported application languages, and appearance themes.
- Crash diagnostics, local token retention, and user-facing deletion/export.
- Minimum supported macOS versions, hardware architectures, and deprecation policy.
- Product-wide success metrics and rollout thresholds.

## Verification Contract

- Every detailed requirement has one canonical domain owner.
- New feature runs link to the owning domain PRD instead of copying broad policy.
- Product behavior changes update the owning PRD and the related ARD when
  architecture or data flow changes.
- Documentation checks validate internal links, required document paths, and
  unresolved template placeholders before completion.
