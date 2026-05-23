# Agent Entry Point

Repo-local Spill instructions remain the source of truth for product direction,
paths, commands, release policy, and macOS-specific constraints. Shared agent
behavior comes from the local AgentPlaybook checkout.

Shared AgentPlaybook library:

- `/Users/taehwankwon/Documents/KeyFlowVault/AgentPlaybook/AGENTS.md`
- `/Users/taehwankwon/Documents/KeyFlowVault/AgentPlaybook/index.md`
- `/Users/taehwankwon/Documents/KeyFlowVault/AgentPlaybook/scripts/workflow.py`

`/Users/taehwankwon/Documents/KeyFlowVault/agent` is a symlink to the same
AgentPlaybook checkout.

Use repo-local Spill instructions first. Use AgentPlaybook only to load the
smallest relevant common, workflow, platform, or review cards for the task. Do
not copy shared playbook content into this repo when a pointer is enough.

Before PRD, ARD, task breakdown, or implementation work:

1. Read `.agents/README.md`.
2. Follow `.agents/workflows/implementation.md`.
3. Apply `.agents/workflows/ambiguity-gate.md`.
4. For safety-sensitive work, follow `VIBEGUARD.md`.

VibeGuard gate:

- Run `npx --yes @taehwandev/vibeguard audit . --rules /Users/taehwankwon/Documents/KeyFlowVault/AgentPlaybook` before and after documentation, code, config, dependency, data, deployment, or credential changes.
- Use `--fix` only for low-risk VibeGuard fixes, then inspect the diff.
- Never print secret values. Ask before destructive data actions, production deploys, signing/notarization credential changes, paid-service/model usage increases, or recurring infrastructure.
