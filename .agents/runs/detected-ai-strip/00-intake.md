# Feature Intake

## Feature ID

`detected-ai-strip`

## Request

The maintainer questioned whether the AI section is useful when it always shows
the same three providers. They clarified that richer local AI monitoring is out
of scope for this slice and that Spill should keep only a small promotional and
glanceable signal. The requested slice is to make Spill's AI strip show only
meaningful local state instead of fixed placeholder rows.

## User Problem

Fixed Codex, Ollama, and OpenAI rows make the compact panel feel noisy when those
tools are not installed, running, or configured. The panel should preserve space
for higher-value controls and avoid implying that Spill is a full AI dashboard.

## Necessity Assessment

Decision: `build`

Reason: This is a small correction to an existing MVP AI strip. It improves panel
signal quality and compactness without adding permissions, private APIs, or
network calls.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none
- researchable: existing AI provider, panel sizing, smoke reports, and product specs
- assumable: command installation can be inferred from executable paths and common Homebrew/user binary directories
- out-of-scope: external AI telemetry integration and external AI service probing

Resolved inputs:

- maintainer: AI should stay lightweight and avoid rich telemetry inside Spill.
- repo-research: the current provider returns three fixed statuses, including missing states, and the panel always renders the AI section.
- assumption: missing AI tools should be omitted entirely rather than shown as grey disabled pills.

## Clarifying Questions

None.

## Target User

Developers and AI-heavy Mac users who may have Codex, Ollama, or OpenAI
configuration available, but who do not need Spill to become a detailed local AI
monitoring dashboard.

## Proposed Product Shape

The compact panel shows the AI section only when at least one local AI signal is
detected. Installed-but-not-running tools render as idle, running tools render as
active, and configured cloud credentials render as configured without exposing
secrets. If no AI signal is detected, the AI section takes no panel space.

## Constraints

- macOS/public API constraints: use local process lists and file/executable checks only.
- permission constraints: no new permissions.
- distribution constraints: no private APIs and no external network calls.
- performance constraints: keep checks cheap and run panel refreshes in the existing background path.

## Non-goals

- Do not add external AI telemetry.
- Do not call OpenAI, Ollama HTTP endpoints, or any external service.
- Do not show missing AI providers as placeholder rows.

## Open Questions

None.

## Decision

Status: `accepted`

Reason: The scope is clear and matches the compact tray direction.
