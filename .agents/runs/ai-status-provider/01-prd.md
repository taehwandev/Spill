# PRD: AI Status Provider

## Summary

Add a compact AI strip to Spill that shows local Codex, Ollama, and OpenAI configuration state.

## Goals

- Show Codex process presence when obvious.
- Show Ollama process presence without network dependency.
- Show whether OpenAI configuration is present without exposing secrets.
- Keep the panel compact after adding the new row.

## Non-Goals

- Do not make external API calls.
- Do not query Ollama HTTP endpoints.
- Do not inspect shell history, prompts, or session contents.
- Do not expose environment variable values.

## User Stories

- As a developer, I can see whether Codex appears to be running.
- As a developer, I can see whether Ollama appears to be running.
- As a developer, I can see whether OpenAI configuration is present.

## Requirements

1. Add model types for local AI tool status.
2. Add a provider that maps process names and environment variables into deterministic statuses.
3. Add a store for cached AI statuses.
4. Render a compact AI strip in the panel.
5. Preserve compact panel layout by converting system status meters into horizontal pills.
6. Add tests for detected, missing, configured, and no-secret states.

## Acceptance Criteria

- Codex, Ollama, and OpenAI all render in the AI strip.
- Missing tools are quiet grey states.
- No secret values appear in `SpillStatusItem`.
- `swift test` passes.
- Panel layout smoke passes.
