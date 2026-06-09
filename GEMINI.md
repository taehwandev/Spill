# Gemini Instructions

Follow `AGENTS.md`.

When running AgentPlaybook workflow, preflight, or finish commands from
Antigravity/AGY, use `SPILL_AI_TOOL=antigravity` or rely on the user-level
environment installed by Spill token metering setup. This keeps safe workflow
labels in Antigravity's label context instead of Codex's label context.

For multi-step work, the route command shape is:

```bash
SPILL_AI_TOOL=antigravity python3 "${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/scripts/workflow.py" route <command> --request "<USER_REQUEST>"
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
