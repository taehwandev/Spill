# Detailed PRD: Detected AI Strip

## PRD Authoring Gate

`00-intake.md` has `Decision: build` and no unresolved clarifying questions.

## Summary

Make the Spill panel AI strip detection-based. The strip should appear only when
Spill can show a useful local AI signal, keeping the panel compact and keeping
rich AI telemetry out of this slice.

## Resolved Inputs

- maintainer decisions: keep the AI feature lightweight and promotional; richer AI monitoring is out of scope.
- repo-researched facts: the current implementation renders Codex, Ollama, and OpenAI rows even when they are missing.
- assumptions: missing tools should be hidden instead of rendered as unavailable pills.

## Goals

- Show active local AI tool processes when detectable.
- Show installed local AI tools as idle when no matching process is running.
- Show OpenAI as configured only when local environment configuration is present.
- Hide the whole AI section when there are no visible statuses.

## Non-goals

- External AI telemetry integration.
- External network checks.
- Secret display.
- Detailed local AI dashboards.

## User Stories

- As a user without local AI tooling, I want the panel to omit AI rows so the tray stays compact.
- As a user with Ollama or Codex installed, I want to see whether the tool is idle or active.
- As a user with OpenAI configuration, I want to know that configuration exists without seeing secret values.

## UX Requirements

### Entry Point

The existing Spill panel remains the entry point. No new navigation or
preference is required for this slice.

### Layout

When one or more AI statuses are visible, the panel shows the existing compact
AI section and renders only those statuses. When none are visible, the AI section
and its divider are omitted.

### States

- loading: existing cached state remains visible until a background refresh completes.
- empty: no AI section is rendered.
- unavailable: missing tools are treated as empty, not visible unavailable rows.
- permission required: not applicable.
- success: installed idle, running active, or configured states render as compact pills.
- failure: process or executable detection failure returns an empty AI state without blocking the panel.

## Functional Requirements

1. Codex and Ollama statuses are visible only when installed or running.
2. Running Codex or Ollama shows an active status.
3. Installed but non-running Codex or Ollama shows an idle status.
4. OpenAI is visible only when a non-empty OpenAI environment configuration is present.
5. Missing AI tools do not render placeholder rows.
6. The panel content report accepts zero AI statuses as valid.
7. The panel accessibility smoke requirements do not require an AI label when the strip is hidden.

## Behavior Scenarios

### Main Path

Given Codex is installed but no Codex process is running
When the user opens the Spill panel
Then the AI strip shows Codex as idle

### Relevant Edge States

Given no Codex, Ollama, or OpenAI configuration is detected
When the user opens the Spill panel
Then the panel omits the AI strip and does not reserve AI section height

## Acceptance Criteria

- Missing AI tools do not appear in the panel.
- Installed local AI tools appear as idle.
- Running local AI tools appear as active.
- OpenAI configuration appears without exposing key values.
- Panel layout and content smoke checks still pass.

## Metrics

- perceived latency: panel opens without waiting for AI detection.
- reliability: detection failures degrade to no visible AI rows.
- resource use: checks stay local and cheap.

## Rollout

- MVP: Codex, Ollama, and OpenAI configuration detection only.
- later: richer telemetry remains outside this slice unless explicitly scoped.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/runs/ai-status-provider`
