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

## Mandatory: Route Before Every Task

**Every task — including direct questions, single-step edits, and reviews —
requires a workflow.py route call before starting work.** This is not optional.
The route call writes the Spill label context so token usage is correctly tagged
by the Stop hook.

The UserPromptSubmit hook writes a baseline `triage/classify` label automatically,
but that label is overwritten only when you run the explicit route below.
If you skip the route, the Stop hook records every event as `analysis/classify`.

### Route command shape

```bash
SPILL_AI_TOOL=claude python3 "${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/scripts/workflow.py" route <command> --request "<USER_REQUEST>"
```

For already-classified requests (second pass, follow-up, or any turn where the
intent is unambiguous without further clarification):

```bash
SPILL_AI_TOOL=claude python3 "${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/scripts/workflow.py" route <command> --request-classified
```

### Command mapping

| User intent | command |
|---|---|
| Question / investigation / analysis | `triage` |
| Bug diagnosis or fix | `bugfix` |
| New feature or code addition | `feature` |
| Refactor or cleanup | `refactor` |
| Code review | `review` |
| Planning or task breakdown | `task` |
| PRD or spec | `prd` |
| Runtime setup, local prompt, hooks, metering install | `workflow-setup` |
| Release or publish | `release` |
| Docs update | `docs` |
| Ambiguous — needs clarification | `ambiguity` |

### When the route command is missing

Do not proceed with editing, reviewing, committing, or running tests until the
route has been executed and the gate ledger from the route output is visible.
If the route produces a `clarify_first` response, ask the user the blocker
question before continuing.
