<!-- BEGIN MANAGED TAO AGENT OS POINTER -->
## Tao Agent OS Pointer

Read this repository's `AGENTS.md` first. It contains the active shared
Tao Agent OS routing block and repo-local priority rules. Keep this file thin:
only runtime-specific notes should live here, and shared workflow or skill
guidance must route through `AGENTS.md`.

<!-- END MANAGED TAO AGENT OS POINTER -->

# Claude Instructions

Follow `AGENTS.md`.

## Mandatory: Build And Adapter Changes

Before answering or changing anything related to app builds, app restarts,
release packaging, token-metering adapters, or runtime hook installation, read
`.agents/build-and-run.md`.

Key rules from that guide:

- `swift build` only compiles the Swift package. It does not create or refresh
  `.build/Spill.app`.
- Use `./scripts/build-app.sh` for the local bundled app, then restart the
  running `.build/Spill.app/Contents/MacOS/Spill` process before claiming UI or
  bundled resource changes are visible.
- Rebuilding the app does not update installed runtime hook scripts under
  `~/Library/Application Support/Spill/adapters`. If Codex, Claude Code, or
  Antigravity/AGY hook behavior changed, verify the source/resource copies and
  reinstall or repair the local adapters before claiming the runtime is using
  the new hook.
- Antigravity/AGY is stored as the canonical `antigravity` tool label. `agy` is
  only an alias.
- Empty AGY stdin can be a normal no-event lifecycle/tool hook call. Do not
  treat it as usage failure unless diagnostics and stored events also show no
  real model usage was recorded.

## Mandatory: Spill Local Usage Status Requests

When the user explicitly asks Claude for `spill`, Spill status, token usage
status, or a local metering summary, run the read-only local stats helper for
Claude Code:

```bash
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool claude
```

Do not answer from memory or from hook/setup status. Return the full aggregate
summary: total, input, output, event count, average event size, peak event size,
workflow label coverage, model/task/stage breakdowns, token detail categories,
and recent activity. Treat `unknown` as unavailable detail attribution, not as a
guessed input category.

This helper is read-only. It is not a usage event, hook, importer, label
handoff, or proof that the current turn was recorded. Do not inspect prompts,
responses, commands, file paths, logs, diffs, source content, environment
values, transcripts, shell history, or secrets to explain the output.

## Routing And Workflow Labels

Follow the active Tao routing block in AGENTS.md for stateless answers,
tracked work, continuation, and delegated-worker classification. Do not add a
separate start requirement for direct questions or follow-ups.

Preserve the existing Spill workflow labels and per-turn fallback. Use the
current Claude runtime label for both; workflow-provided labels take precedence.
Label handoff is separate from lifecycle admission and does not authorize work.
When invoking workflows that provide labels, preserve SPILL_AI_TOOL=claude and
SPILL_TOKEN_USAGE_AI_TOOL=claude; keep the per-turn fallback with --if-absent.
