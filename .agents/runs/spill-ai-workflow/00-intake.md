# Feature Intake: Spill AI Workflow

## Request

Refine the AI feature direction and continue into implementation without
AgentCat integration. The feature should make Spill's existing AI strip more
useful than a passive installed/running display. The first implementation slice
should use Spill-owned local tool state and safe local actions only.

## User Problem

The current AI strip answers whether a tool is installed, running, or configured,
but it does not help the user decide what to do next. A useful compact tray
should turn those signals into immediate actions such as starting the right local
tool, checking service status, or understanding what capability is available.
Future project/path usage should be based on Spill-owned local state or explicit
user action history, not an unrelated dashboard dependency.

## Necessity Assessment

Assessment:

- Necessary for current direction: yes; it makes the AI strip more actionable.
- Better solved by Spill: yes for local status-to-action guidance.
- Compact enough: yes; details stay in the existing popover.
- Private API or permission impact: none for the MVP.
- If not built: the AI strip remains mostly decorative status display.

Decision: `build`

Reason: This fits Spill's product direction as a compact local control tray. The
MVP is small, uses existing AI detection, avoids private APIs, does not require
new permissions, and avoids external telemetry or paid services.

## Ambiguity Gate

Use `.agents/workflows/ambiguity-gate.md` before PRD authoring.

Clarity: `clear`

Unknown classification:

- blocker: none
- researchable: exact UI insertion points and existing panel detail patterns
- assumable: launch commands can be copied first instead of executed directly
- out-of-scope: AgentCat integration, prompt/log ingestion, usage dashboard

Resolved inputs:

- maintainer: AgentCat is not related to this implementation direction.
- repo-research: Spill already has `LocalAIStatusProvider`, `AIStatusStore`,
  AI pills, status detail popovers, server-status badges, and pasteboard
  patterns in update flows.
- assumption: the safest first useful slice is "suggested next action + copy
  command" in the AI detail popover, because it is reversible and does not launch
  shell commands or read private data.

## PRD Authoring Gate

PRD authoring is allowed. User intent, expected behavior, value, UI scope,
feasibility, permission impact, and distribution impact are resolved.

## Clarifying Questions

Questions: none.

## Target User

Developers and AI-heavy Mac users who keep Codex, Claude, Ollama, Antigravity,
or OpenAI configuration available and want a compact tray to move from status to
action quickly.

## Proposed Product Shape

The AI strip remains compact. Clicking an AI tool opens detail with safe metadata
and a next-step recommendation. When the tool has a known local command, the
detail popover provides a copy-command action so the user can paste it into the
terminal they choose. Later slices can add a local Spill AI journal for
Spill-launched workspaces.

## Constraints

- macOS/public API constraints: use public AppKit/SwiftUI APIs only.
- permission constraints: no new Accessibility, Screen Recording, or file access
  requirement.
- distribution constraints: no private APIs, no shell execution in the MVP.
- performance constraints: reuse existing local detection cadence; no
  high-frequency polling.

## Non-goals

- AgentCat integration.
- Prompt, response, raw log, token payload, or secret display.
- A large usage dashboard.
- Automatic command execution or terminal control.
- New network calls, telemetry uploads, paid services, or recurring
  infrastructure.

## Open Questions

- Future path usage needs a Spill-owned local journal design before
  implementation.

## Decision

Status: `accepted`

Reason: This produces immediate user value while preserving privacy and compact
tray scope.
