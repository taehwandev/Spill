# Detailed PRD: Spill AI Workflow

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, `Clarity: clear`, and no blocker
questions.

## Summary

Make the existing AI strip action-oriented. Spill should not only say "Codex is
ready" or "Ollama is running"; it should show the safe next step the user can
take from the compact tray. The MVP adds next-step recommendations and
copy-command actions to AI status details, using only local tool state that Spill
already detects.

## Resolved Inputs

- maintainer decisions: AgentCat is unrelated and should not be part of this
  implementation.
- repo-researched facts: Spill already detects Codex, Claude, Antigravity,
  Ollama, and OpenAI configuration; AI details already show status, model,
  version, and source; update flows already use safe pasteboard actions.
- assumptions: copying a launch command is safer for the MVP than executing it,
  because it avoids terminal automation, shell side effects, and permission
  questions.

## Goals

- Turn local AI status into clear next-step guidance.
- Add safe per-tool actions in the AI detail popover.
- Keep the compact AI strip visually lightweight.
- Avoid exposing prompts, responses, secrets, raw logs, or private files.
- Keep AgentCat out of this implementation path.

## Non-goals

- Usage analytics dashboard.
- Path/project usage ranking in this slice.
- Automatic shell execution, terminal launching, or command injection.
- New network calls beyond the existing user-triggered service status check.
- New permissions or background telemetry.

## User Stories

- As a developer, I want to click Codex in Spill and know the safest next action
  without reading status details manually.
- As a local Ollama user, I want Spill to distinguish "server running" from
  "ready to start" and give me the relevant command.
- As a privacy-sensitive user, I want no prompt text, API key, or raw local log
  to appear in the compact panel.
- As a user with multiple AI tools installed, I want the AI strip to remain
  compact and not become a dashboard.

## UX Requirements

### Entry Point

The existing AI strip remains the entry point. Clicking any AI pill opens its
existing status detail popover.

### Layout

The compact AI pill layout stays unchanged for the MVP. The status detail
popover gains:

- a `Next` row with a concise recommendation;
- a copy-command button when a safe local command exists;
- the existing status/model/version/source rows.

The detail popover must remain compact and fit the existing panel style.

### States

- loading: existing AI strip keeps the previous state while refresh happens.
- empty: hide the AI strip when no local AI tools or OpenAI configuration are
  detected.
- unavailable: do not show a tool when it is not installed/configured.
- permission required: not applicable for the MVP.
- success: detail shows next action and optional copy-command button.
- failure: no command execution occurs, so failure is limited to pasteboard
  unavailability; the UI keeps the status details visible.

## Functional Requirements

1. Each visible local AI tool status must expose a safe next-action
   recommendation.
2. Installed-but-idle command-line AI tools should recommend starting from a
   terminal command.
3. Running command-line AI tools should recommend continuing the active local
   session or using the service/status detail when relevant.
4. Ollama should recommend `ollama serve` when ready and `ollama list` when
   running.
5. OpenAI configuration should not expose key values and should not offer a
   command that prints secrets.
6. The copy-command button must only copy static safe command text, not values
   derived from secrets or raw process command lines.
7. Detail rows and actions must be testable without launching the app.
8. AgentCat must not be queried or referenced by the feature.

## Behavior Scenarios

### Main Path

Given Codex is installed but no Codex process is running
When the user opens the Codex detail popover
Then Spill shows `Next: Start from terminal` and a copy action for `codex`

### Running Tool

Given Ollama is running
When the user opens the Ollama detail popover
Then Spill shows a running-state recommendation and a copy action for
`ollama list`

### Sensitive Configuration

Given OpenAI API configuration is present
When the user opens OpenAI API detail
Then Spill shows configuration status without API key values and does not offer a
secret-printing command

### No AI Tools

Given no supported AI tool or configuration is detected
When the panel opens
Then the AI strip remains hidden

## Acceptance Criteria

- AI detail rows include a `Next` recommendation for visible AI statuses.
- Safe command actions exist for Codex, Claude, Antigravity, and Ollama.
- OpenAI detail does not expose secrets or copy secret-reading commands.
- No AgentCat command, model, type, or dependency is introduced.
- Focused tests cover recommendation mapping and secret-safe rows.

## Metrics

- perceived latency: detail opens immediately; no command execution is required.
- reliability: recommendations derive from already-detected local state.
- resource use: no new polling or external service calls.

## Rollout

- MVP: next-action row and copy-command action in AI detail popovers.
- later: local Spill AI journal for explicit Spill-launched workspaces, user
  privacy controls for path display, and optional "recent workspace" surfacing.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `Sources/Spill/Providers/LocalAIStatusProvider.swift`
- `Sources/Spill/Panel/SpillStatusDetailModels.swift`
- `Sources/Spill/Panel/SpillStatusDetailPopover.swift`
