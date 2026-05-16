# ARD: AI Status Provider

## Architecture

Add a local provider layer for AI tool state:

- `LocalAIToolKind`
- `LocalAIToolStatus`
- `LocalAIStatusProvider`
- `AIStatusStore`

The provider maps injected process names and environment values for tests. At runtime it reads local process command names through `/bin/ps -axo comm=` and checks only selected environment variable presence.

## Runtime Reads

- Codex: process name `codex` or path ending in `/codex`.
- Ollama: process name `ollama` or path ending in `/ollama`.
- OpenAI: non-empty `OPENAI_API_KEY` or `OPENAI_BASE_URL`.

## UI

`SpillBarView` renders a compact AI row below the system status row. To keep the panel compact, system status modules now render as horizontal pills instead of stacked meters.

## Security

OpenAI detection stores only `Set` or `Missing`; it does not retain or render secret values.

## Risks

- Process-name detection is best effort.
- GUI-launched apps may not inherit shell OpenAI environment variables.
- Codex session content is intentionally not inspected.

## Verification

- Unit tests cover provider mapping and store refresh.
- Panel layout smoke confirms the added row remains compact.
