# Detailed ARD: AI Tool Metadata

## Architecture Summary

Extend `LocalAIStatusProvider` with optional metadata collected from safe local
sources. SwiftUI remains unchanged except for the existing subtitle/detail rows:
the provider enriches `LocalAIToolStatus`, and the detail model renders model,
version, and source rows when present.

## Decisions

### D1: Metadata Is Best Effort

Decision: Show model and version only when local commands or visible process
arguments expose them.

Rationale: Exact AI session state is not reliably available across tools without
reading private state or transcripts.

Alternatives considered: Parse each tool's private config/session files. Rejected
because it risks secrets, instability, and overpromising.

### D2: OpenAI Means API Configuration

Decision: Display OpenAI as `OpenAI API` and read only explicit OpenAI model
environment keys.

Rationale: Codex/GPT session state is separate from generic OpenAI API
configuration.

## Modules Affected

- `Sources/Spill/Providers/LocalAIStatusProvider.swift`
- `Sources/Spill/Panel/SpillStatusDetailModels.swift`
- `Tests/SpillTests/LocalAIStatusProviderTests.swift`
- `Tests/SpillTests/SpillStatusDetailRowsTests.swift`
- `Tests/SpillTests/SpillPanelAccessibilityReportTests.swift`

## New Types / APIs

- `LocalAIToolMetadata`
- `LocalOllamaRuntimeSummary`
- local command metadata readers hidden inside the provider file

## Data Flow

```text
ps/process args + local command probes + environment -> LocalAIStatusProvider -> AIStatusStore -> AI strip/detail popover
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: none.
- Network: no external calls.
- File system: local executable checks only.

## Failure Modes

- command timeout: omit version/model metadata.
- unsupported model argument shape: omit model metadata.
- no active Ollama model: omit Ollama model metadata.

## Performance Notes

- Metadata refresh runs through the existing detached AI status refresh path.
- Local command probes use short timeouts.
- The panel still renders cached state while refresh is pending.

## Test Strategy

### Automated

- Provider tests for Claude, Gemini, Ollama, and OpenAI API metadata.
- Detail row tests for model/version/source.
- Existing panel report and layout tests remain applicable.

### Manual

- Open the panel on a machine with Codex, Claude, Gemini, and Ollama installed.
- Confirm metadata appears only when safely detected.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Provider metadata | builder | `LocalAIStatusProvider.swift`, provider tests | No |
| Detail visualization | builder | `SpillStatusDetailModels.swift`, detail tests | No |

## Risks

- CLI version output formats can change.
- Some CLI sessions do not expose model selection in process arguments.
- GUI-launched Spill may have a narrower `PATH` than the user's shell.
