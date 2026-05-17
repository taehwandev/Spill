# Agent Briefs: AI Tool Metadata

## Builder Brief

Goal: enrich the compact AI strip with safe local metadata for Codex, Claude,
Gemini, Ollama, and OpenAI API configuration.

Implementation constraints:

- Keep all probes local.
- Do not inspect transcripts, private session stores, or secret-bearing configs.
- Add short timeouts to command probes.
- Preserve hidden-empty AI strip behavior from `detected-ai-strip`.

Verification:

- `swift test --filter LocalAIStatusProviderTests`
- `swift test --filter SpillStatusDetailRowsTests`
- Full test and workflow gates after integration.
