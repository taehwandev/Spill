# Spill Implementation Workflow

This workflow is for Codex/agents and human contributors.

## Working Mode

Work in small vertical slices. Each slice should leave the app buildable and usable.

Before implementing any feature unit, complete the intake necessity check. If intent, scope, product value, UI behavior, permission impact, or distribution impact is unclear, ask the maintainer one to three concise questions and wait for a decision before implementation.

Default command checks:

```bash
swift build
./scripts/build-app.sh
open .build/Spill.app
```

Do not keep long-running app processes around after verification unless the user needs to try the app.

## Phase 0: Reset Product Direction

Goal:

Remove fragile spacer assumptions and align the codebase with the PRD/ARD.

Tasks:

- Remove spacer `NSStatusItem` code.
- Keep one fixed-width trigger item.
- Keep `MenuBarNotchGeometry` only for panel placement and notch-candidate detection.
- Update README language to stop promising physical menu bar recovery.

Acceptance:

- `StatusItemController` owns one `NSStatusItem`.
- No status item length is derived from notch width.
- `swift build` passes.

## Phase 1: Panel Shell

Goal:

Turn Spill Bar into a compact control tray.

Tasks:

- Create panel sections:
  - status strip
  - AI strip
  - pinned actions
  - window actions
- Keep the panel visually compact.
- Preserve permission/empty states.

Acceptance:

- Panel opens quickly.
- Panel does not exceed compact height target unless content requires scrolling.
- No nested cards.
- No large dashboard layout.

## Phase 2: Provider Models

Goal:

Introduce model layer before adding more UI complexity.

Tasks:

- Add `SpillStatusItem`.
- Add `SpillAction`.
- Add provider protocols or lightweight provider structs.
- Convert current menu bar scanner output into action models where needed.

Acceptance:

- SwiftUI views render plain models.
- Provider logic is testable without opening the panel.
- No provider directly manipulates UI.

## Phase 3: System Status Provider

Goal:

Add useful built-in status signals.

Initial metrics:

- CPU
- Memory
- Battery
- Network

Tasks:

- Implement lightweight sampling.
- Cache recent snapshots.
- Avoid high-frequency polling.
- Show unavailable state when APIs fail.

Acceptance:

- Metrics display in compact pills.
- UI remains responsive.
- Sampling interval is conservative.

## Phase 4: AI Status Provider

Goal:

Expose local AI tool state without becoming a network dashboard.

Initial signals:

- Codex process/session presence
- Ollama process presence
- OpenAI configuration presence

Tasks:

- Implement safe local detection.
- Avoid showing secret values.
- Keep network checks opt-in.

Acceptance:

- Missing tools show quietly.
- Detected tools show short, useful labels.
- No external calls happen by default.

## Phase 5: Pinned Actions

Goal:

Make Spill useful for simple icon/action storage.

Tasks:

- Let users pin detected items.
- Let users pin apps by bundle identifier later.
- Render pinned actions prominently.
- Add click result feedback.

Acceptance:

- User can pin/unpin.
- Click success/failure is visible.
- Fallback to app activation exists.

## Phase 6: Window Quick Actions

Goal:

Replace a small subset of window movement utilities.

Actions:

- Left half
- Right half
- Center
- Maximize
- Next display
- Restore previous frame

Tasks:

- Implement focused-window lookup with AX.
- Implement frame setting.
- Store previous frame best-effort.
- Add permission disabled state.

Acceptance:

- Works on common app windows.
- Special windows fail gracefully.
- No hotkeys required for MVP.

## Phase 7: Preferences

Goal:

Keep configuration small but sufficient.

Preferences:

- enable/disable strips
- refresh interval
- manage pinned actions
- permission diagnostics
- launch at login
- optional hotkey

Acceptance:

- Preferences remain simpler than the main panel.
- Users can recover from missing permissions.

## Phase 8: Packaging

Goal:

Make a distributable open-source macOS app.

Tasks:

- Add app icon.
- Add proper bundle metadata.
- Add Developer ID signing path.
- Add notarization script or release checklist.
- Add DMG packaging.
- Document Homebrew Cask path.

Acceptance:

- Local unsigned dev build works.
- Release build path is documented.
- Notarization prerequisites are explicit.

## Verification Checklist

For every feature slice:

- `swift build`
- launch app
- open panel
- confirm no UI overlap
- confirm permission fallback
- confirm app termination works

For AX/window features:

- no Accessibility permission
- with Accessibility permission
- unsupported target window/item
- stale detected item

For distribution changes:

- clean build
- bundle launches from Finder
- Gatekeeper/notarization instructions updated

## Agent Task Template

Use this shape for future agent tasks:

```markdown
## Task

Implement <small vertical slice>.

## Necessity

Decision: build | defer | reject | needs-clarification

Reason:

Clarifying questions asked:
- none, or list the questions and answers

## Context

Read:
- .agents/specs/prd.md
- .agents/specs/ard.md
- relevant source files

## Scope

Change:
- file/module list

Do not change:
- unrelated UI
- private API behavior
- distribution scripts unless required

## Acceptance

- expected behavior
- commands to run
- manual checks
```

## Stop Conditions

Stop and reassess if:

- implementation requires private APIs;
- a feature needs Screen Recording permission;
- a feature cannot work reliably with public APIs;
- panel starts becoming a large dashboard;
- macOS hides the trigger item because of status item length/ordering.
