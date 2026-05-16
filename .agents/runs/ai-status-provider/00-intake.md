# Intake: AI Status Provider

## Feature ID

`ai-status-provider`

## Request

Continue the roadmap after the System strip milestone by adding the local AI strip. The first useful slice should expose Codex, Ollama, and OpenAI configuration state without external calls or secret disclosure.

## User Problem

Users working with local AI tools need quick state awareness while staying in the compact Spill panel. They should not have to switch to Terminal just to see whether obvious local tooling is running or configured.

## Target User

Developers and power users who run Codex, Ollama, or OpenAI-backed tooling locally.

## Proposed Product Shape

The panel shows a compact AI row with three short pills: Codex, Ollama, and OpenAI. Running/configured tools use active or normal tinting; missing tools stay quiet and grey.

## Constraints

- macOS/public API constraints: use local process/environment reads only.
- permission constraints: do not add Accessibility, Screen Recording, or network permission requirements.
- distribution constraints: do not require helper tools.
- performance constraints: keep reads local and refresh only with panel refresh.

## Non-goals

- No network checks.
- No secret values in UI, logs, or model state.
- No chat/session introspection.
- No model inventory or token usage.

## Open Questions

- None for this MVP slice.

## Decision

Decision: `build`

Reason: Local AI state is a planned roadmap milestone and can be implemented safely with local process and environment detection.
