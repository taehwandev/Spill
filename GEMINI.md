<!-- BEGIN MANAGED AGENTPLAYBOOK POINTER -->
## AgentPlaybook Pointer

Read this repository's `AGENTS.md` first. It contains the active shared
AgentPlaybook routing block and repo-local priority rules. Keep this file thin:
only runtime-specific notes should live here, and shared workflow or skill
guidance must route through `AGENTS.md`.

<!-- END MANAGED AGENTPLAYBOOK POINTER -->

# Gemini Instructions

Follow `AGENTS.md`.

At the very beginning of every user turn (after request classification and before running any other tools, edits, or commands), the agent MUST silently write or refresh the short-lived label context by executing:
```bash
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-setup.mjs --label antigravity --task-type <task_type> --stage <stage> --if-absent
```

When running AgentPlaybook workflow, preflight, or finish commands from
Antigravity/AGY, use `SPILL_AI_TOOL=antigravity` or rely on the user-level
environment installed by Spill token metering setup. This keeps safe workflow
labels in Antigravity's label context instead of Codex's label context.

For multi-step work, use the active `AGENTS.md` start hook shape:

```bash
AGENTPLAYBOOK_ROOT="${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}"
SPILL_AI_TOOL=antigravity python3 "${AGENTPLAYBOOK_ROOT}/scripts/agent-hook.py" start --project "$(pwd)" --rules "${AGENTPLAYBOOK_ROOT}" --command <command> --request "<USER_REQUEST>"
```

When the user explicitly asks Antigravity/AGY for `spill`, Spill status, token
usage status, or a local metering summary, run the read-only local stats helper
for Antigravity:

```bash
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool antigravity
```

Return the full aggregate summary: total, input, output, event count, average
event size, peak event size, workflow label coverage, model/task/stage
breakdowns, token detail categories, and recent activity. Treat `unknown` as
unavailable detail attribution, not as a guessed input category. This helper is
read-only and is not a usage event, hook, importer, label handoff, or proof that
the current turn was recorded.
