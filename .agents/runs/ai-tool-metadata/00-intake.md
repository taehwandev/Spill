# Feature Intake

## Feature ID

`ai-tool-metadata`

## Request

The maintainer asked whether Spill can show which model or version Ollama, GPT,
Codex, Claude, and Gemini are using. The request also asks for a compact
visualization rather than a large AI dashboard. The implementation should expose
only safe local hints and keep Agent Cat as the richer telemetry product.

## User Problem

An active AI status pill is more useful when it can explain which local model,
CLI version, or API default model is visible. Without this, the strip only says
that a process exists.

## Necessity Assessment

Decision: `build`

Reason: This is a small enhancement to the existing AI strip. It adds useful
metadata without external calls, new permissions, or a dashboard layout.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none
- researchable: existing AI provider model, current command detection, product no-secret rules
- assumable: model/version should be best-effort hints and can show `N/A` implicitly by omission
- out-of-scope: exact session reconstruction, transcript inspection, private config scraping, external API calls

Resolved inputs:

- maintainer: include Claude and Gemini when installed or running.
- maintainer: expose Ollama/Codex/GPT model or version if safely knowable.
- repo-research: OpenAI currently means API configuration, not a Codex session.
- assumption: OpenAI should be labeled as API configuration to avoid confusing it with Codex/GPT sessions.

## Clarifying Questions

None.

## Target User

Developers running local or CLI-based AI tools who want quick awareness of which
tool and model context is active.

## Proposed Product Shape

The AI strip keeps its compact chip layout. Each detected tool may show a model
or version in the chip subtitle. The detail popover shows safe rows for status,
model, version, and metadata source when available.

## Constraints

- macOS/public API constraints: use local process lists and local command execution only.
- permission constraints: no new permissions.
- distribution constraints: no private APIs and no external network calls.
- performance constraints: command probes must be short, cached through the existing store path, and timeout quickly.

## Non-goals

- Do not inspect chat transcripts.
- Do not parse secret-bearing private config files.
- Do not call OpenAI, Anthropic, Gemini, or external APIs.
- Do not build Agent Cat-style telemetry inside Spill.

## Open Questions

None.

## Decision

Status: `accepted`

Reason: The slice improves signal quality while preserving the compact tray and
privacy constraints.
