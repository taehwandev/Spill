# Feature Intake

## Feature ID

`manual-update-check`

## Request

Define and implement Spill's MVP update path. The maintainer wants an update
button in the app, a version check, and a lightweight update source without
running a custom server. The agreed direction is a static update manifest that
is generated during release and checked only when the user asks. Follow-up:
improve the panel update UI and make the update install path available as a
Terminal command instead of silently executing shell work inside the app.

## User Problem

Users need to know when a newer Spill build exists without manually comparing
GitHub release versions. Maintainers need update metadata to move with the
existing release process rather than operating a new backend.

## Necessity Assessment

Decision: `build`

Reason: Manual update checks fit the direct-distribution path, require no
private APIs, and avoid the complexity of Sparkle until Developer ID signing and
notarization are ready.

## Ambiguity Gate

Use `.agents/workflows/ambiguity-gate.md` before PRD authoring.

Clarity: `clear`

Unknown classification:

- blocker: none
- researchable: existing release workflow, package script, bundle version, and
  Preferences/menu entry points
- assumable: use GitHub Releases latest asset URL as the static manifest source;
  show update status in Preferences; make menu item open Preferences and start
  a manual check; keep any panel update affordance compact; copy the public
  install command to the clipboard instead of running it automatically
- out-of-scope: automatic update installation, Sparkle appcast, background
  polling, Homebrew Cask update behavior, silent shell execution from the app

Resolved inputs:

- maintainer: Add an update button and version check; no custom server should
  be required.
- repo-research: releases already produce stable GitHub latest assets; app
  bundle versions are written by `scripts/build-app.sh`; Preferences and the
  status item context menu already host maintenance controls; `docs/install.sh`
  supports the public Terminal install path.
- assumption: GitHub Releases can host `update.json` as a stable latest asset
  for MVP. The hosted Pages site can link to the same assets later without
  changing app code.

No blocking questions remain.

## PRD Authoring Gate

The detailed PRD can be authored because the user intent, behavior, UI scope,
feasibility, permission impact, and distribution impact are resolved.

## Clarifying Questions

Questions:

- None.

## Target User

Users installing Spill outside the Mac App Store, especially testers using
GitHub Releases.

## Proposed Product Shape

Preferences shows the current version, a Check for Updates button, a Terminal
install command, and a DMG download action only after a newer manifest version is
detected. The compact panel may show a narrow update row after a successful
available update check, prioritizing command copy over direct download. The menu
bar context menu and app menu include Check for Updates, which opens Preferences
and starts the same check.

## Constraints

- macOS/public API constraints: use Foundation networking, AppKit URL opening,
  and the pasteboard for command copy only.
- permission constraints: no Accessibility or Screen Recording changes.
- distribution constraints: keep direct GitHub Releases distribution; do not
  require Developer ID for the manual check.
- performance constraints: no background polling; one short network request per
  user action.

## Non-goals

- Automatic update installation.
- Automatically running the Terminal install command.
- Sparkle integration.
- Custom update server.
- Editing the landing page currently being changed by another agent.

## Open Questions

- Whether the future Sparkle implementation should default automatic checks on
  or off remains a later distribution decision.

## Decision

Status: `accepted`

Reason: The MVP path is clear, reversible, and aligned with the existing release
automation.
