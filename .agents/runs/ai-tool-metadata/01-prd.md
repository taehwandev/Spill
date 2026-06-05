# Detailed PRD: AI Tool Metadata

## PRD Authoring Gate

`00-intake.md` has `Decision: build` and no unresolved clarifying questions.

## Summary

Add best-effort model and version metadata to Spill's compact AI strip. The
feature must clarify that OpenAI is API configuration, while Codex, Claude,
Gemini, and Ollama are local command/process states.

## Resolved Inputs

- maintainer decisions: show Claude and Gemini in addition to Codex, Ollama, and OpenAI API.
- repo-researched facts: the current AI strip already hides missing tools and supports detail popovers.
- assumptions: model/version metadata should be shown only when safely exposed by local commands, process arguments, or explicit environment keys.

## Goals

- Detect Claude and Gemini CLI tools.
- Show CLI version hints when `--version` returns quickly.
- Show process-argument model hints such as `--model` or `-m` when visible.
- Show the current Ollama runtime model from `ollama ps` when available.
- Rename OpenAI display semantics to API configuration and show explicit OpenAI model environment values when present.

## Non-goals

- Exact session reconstruction.
- External network model lookup.
- Secret display.
- External AI telemetry.

## User Stories

- As a user running Ollama, I want to see the loaded model name in the AI strip.
- As a user running Codex, Claude, or Gemini, I want to see a model hint if the process exposes it.
- As a user with OpenAI API configuration, I want it labeled clearly as API configuration rather than a running Codex session.

## UX Requirements

### Entry Point

The existing AI strip and detail popover remain the entry point.

### Layout

The chip subtitle shows the best available model or version. The detail popover
adds rows for model, version, and source when available.

### States

- loading: existing cached AI status remains until background refresh finishes.
- empty: AI strip remains hidden.
- unavailable: missing tools remain hidden.
- permission required: not applicable.
- success: safe model/version metadata is shown.
- failure: command timeouts or unsupported tools omit metadata without blocking the panel.

## Functional Requirements

1. Claude and Gemini are visible when installed or running.
2. Running Codex, Claude, Gemini, and Ollama are active.
3. Installed but non-running Codex, Claude, Gemini, and Ollama are idle.
4. `--model`, `--model=value`, and `-m value` process arguments are parsed as model hints.
5. `ollama ps` is parsed for the current active model.
6. `--version` output is parsed for local CLI version hints.
7. OpenAI API model hints come only from explicit OpenAI model environment keys.
8. No secret values, transcripts, private configs, or external network calls are read.

## Behavior Scenarios

### Main Path

Given Claude is running with `--model claude-sonnet-4-5`
When the panel refreshes AI status
Then the Claude chip shows `Active` with `claude-sonnet-4-5` as the subtitle

### Relevant Edge States

Given a tool is installed but `--version` times out
When the panel refreshes AI status
Then the tool still appears as idle or active without version metadata

## Acceptance Criteria

- Claude and Gemini are covered by provider tests.
- Model and version detail rows are covered by detail row tests.
- OpenAI is labeled as API configuration.
- Full Swift tests and workflow gates pass.

## Metrics

- perceived latency: panel open does not wait on metadata commands.
- reliability: command failures degrade to missing metadata.
- resource use: local command probes timeout quickly.

## Rollout

- MVP: local process, command version, command argument, and Ollama runtime metadata only.
- later: optional external telemetry integration can provide richer telemetry.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/runs/detected-ai-strip`
