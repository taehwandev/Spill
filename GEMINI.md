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
