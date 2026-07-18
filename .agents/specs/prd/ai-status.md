# AI Status PRD

## Document Contract

- Status: active
- Audience: product, design, engineering, and QA
- Purpose: define local AI tool status and official service-status presentation
- Source of truth: this document owns AI status requirements outside token usage accounting
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md),
  [Token Metering Dashboard](token-metering/dashboard.md)

## Initial Signals

- Codex process/session state where locally detectable.
- Claude process/session state where locally detectable.
- Gemini process/session state where locally detectable.
- Ollama running/not running.
- Ollama model hint if cheaply detectable.
- OpenAI API configuration present/missing, without revealing secrets.
- Local token metering summary.
- Best-effort tool version and model hints when exposed by local commands or
  visible process arguments.

## Layout Requirements

- The strip is a compact cluster of AI tool status pills plus one token usage
  summary pill.
- The AI area may include a small process-state visualization that shows how
  many supported AI tools are visible and how they are distributed by safe local
  status such as running, ready, or unavailable.
- The token summary appears in the same AI strip, after local tool status, and
  may wrap to a second compact line only when the panel width requires it.
- Clicking the token summary opens the local token dashboard helper.
- If no AI tool is detected but token metering data exists, the AI strip remains
  visible with the token summary.

## Behavior Requirements

- No external API calls in MVP unless explicitly configured.
- The existing official AI service-status check remains user-triggered. Opening
  its detail popover may refresh stale status, and its refresh button may force
  a refresh, but neither surface may add a background polling loop.
- The main Spill process is the only owner of official service-status network
  requests. The separate `Spill - AI Token Metering` helper requests a refresh
  from the main process, then reloads the shared app-owned local status cache
  after a content-free process notification.
- Official service status is informational local display state. It must not be
  written to the Spill server, Private Usage Upload, web dashboard, telemetry,
  settings sync, token usage events, or agent-facing summaries.
- An open compact panel and an open local AI dashboard must converge on the
  same newer official-status snapshot without restart, reopen, manual upload
  sync, or duplicate official network requests from the helper.
- The service-status popover should turn the cached result into a deterministic
  next step: inspect affected official services when an incident exists, check
  local process/setup details when official services are healthy, and offer
  refresh/status-page recovery when official status is incomplete.
- Never display API keys.
- Treat AI providers as pluggable.
- Show Codex, Claude Code, and Antigravity/AGY cards in that fixed order,
  filtered only by the shared AI tool visibility preference. Runtime detection
  enriches the matching card with running process and metadata state; it does
  not control card presence or ordering.
- The process-state visualization must be derived from existing local process
  and configuration status. It must not inspect prompts, transcripts, commands,
  file paths, repository names, shell history, logs, diffs, source content, or
  secret-bearing config values.
- Hide the AI strip only when no local AI tool, OpenAI configuration, or token
  metering state exists.
- Treat model and version labels as best-effort hints, not guaranteed session
  truth.

## Acceptance

- AI strip shows useful local state.
- AI status can be understood at a glance through both status pills and a small
  process-state chart/count summary.
- Token metering placement is visually and conceptually part of AI status.
- A missing runtime does not create an error or reorder the panel. Its neutral
  display card remains presentation-only and does not make Setup or history
  import report the runtime as installed.
- Opening or refreshing official service status in either local dashboard uses
  one main-process network fetch and updates both running surfaces from the
  local cache notification path.
- Official service-status checks create no server record, cloud sync payload,
  background poller, paid model/API call, or token usage event.
- The shared service-status popover explains the useful next action for
  healthy, incident, loading/not-fetched, and incomplete states.

## Verification

- Verify tool card presence and ordering independently from runtime detection.
- Verify one main-process service-status fetch updates both local surfaces.
- Verify official status never enters token, telemetry, upload, web, or
  agent-facing data contracts.
