# Agent Entry Point

Repo-local Spill instructions remain the source of truth for product direction,
paths, commands, release policy, and macOS-specific constraints. Agent workflow
guidance comes from the local AgentPlaybook checkout; do not keep repo-local
workflow overlays when a shared AgentPlaybook card covers the same behavior.

Shared AgentPlaybook library:

- Default root: `~/Documents/KeyFlowVault/AgentPlaybook`
- If the checkout lives elsewhere, set `AGENTPLAYBOOK_HOME` to that root.
- `${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/AGENTS.md`
- `${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/index.md`
- `${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/scripts/workflow.py`
- `${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/scripts/agent-preflight.py`
- `${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/scripts/agent-finish-check.py`

`~/Documents/KeyFlowVault/agent` may be a symlink to the same AgentPlaybook
checkout.

Use repo-local Spill instructions for product and command details. Use
AgentPlaybook for common, workflow, platform, and review cards. Load the
smallest relevant shared cards and link to them instead of copying shared
workflow guidance into this repo.

Routing and executable evidence:

- For multi-step tasks, run
  `python3 "${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/scripts/workflow.py" route <command> --request "<USER_REQUEST>"`
  before selecting shared docs, editing, reviewing, committing, or reporting
  completion. If the current request is a direct question, answer it first, then
  route with `--request-classified` and record that evidence.
- When the wrappers are available, run `agent-preflight.py` before editing,
  reviewing, committing, or reporting completion, and run `agent-finish-check.py`
  before final report, commit, release, or handoff. Pass evidence for every
  required route gate.
- Wrapper evidence under `.agentplaybook/` is local runtime evidence, not source.
- Use human-visible gate signals: 🐱🔵 PENDING, 🐱🟢 GREEN, 🐱🟡 YELLOW, 🐱🔴 RED.

Before PRD, ARD, task breakdown, or implementation work:

1. Read `.agents/README.md`.
2. Read `.agents/specs/prd.md` and `.agents/specs/ard.md`.
3. Follow the relevant AgentPlaybook workflow cards, starting from
   `${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/workflows/agent-task-lifecycle.md`.
4. Apply the shared AgentPlaybook ambiguity gate before PRD, ARD, task
   breakdown, implementation planning, or code work when scope or intent is
   unclear.
5. For safety-sensitive work, follow `VIBEGUARD.md`.

VibeGuard gate:

- Run `npx --yes @taehwandev/vibeguard audit . --rules "${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}"` before and after documentation, code, config, dependency, data, deployment, or credential changes.
- Use `--fix` only for low-risk VibeGuard fixes, then inspect the diff.
- Never print secret values. Ask before destructive data actions, production deploys, signing/notarization credential changes, paid-service/model usage increases, or recurring infrastructure.

<!-- vibeguard:start version=1 -->
## VibeGuard

For every task that may change code, configuration, dependencies, data,
deployment, or credentials:

1. Run `vibeguard audit .` before editing.
2. If the audit reports stale VibeGuard guardrails, run `npx --yes @taehwandev/vibeguard@latest update .` once, then rerun `vibeguard audit .`. The default refresh interval is 7 days; do not update more often unless the user asks or the audit reports stale guardrails.
3. If `vibeguard` is unavailable, run `npx --yes @taehwandev/vibeguard@latest audit .` instead and use the same `npx --yes @taehwandev/vibeguard@latest ...` form for fixes.
4. If fixable findings exist, run `vibeguard audit . --fix` before implementing.
5. Never print detected secret values. Keep real secrets only in ignored runtime env files and keep env templates such as `.env.example` and `.env.sample` value-free.
6. Ask before deleting data, running migrations, deploying to production, increasing paid API/model usage, adding recurring infrastructure, or changing credentials.
7. Prefer cost-aware architecture. Before adding a paid service, database, queue, background worker, model call, analytics SDK, or cloud resource, explain why existing code or a simpler local/server-side design is insufficient.
8. For web apps, commonize repeated API/model/provider calls behind shared server-side helpers or endpoints. Prefer server-side caching, batching, and rate limits before adding new client-side call paths.
9. Before commit or push, verify `git remote -v`, repository visibility, and changed files. If the repository is public or visibility is unknown, stop before pushing secrets, env files, credentials, deployment, infrastructure, or paid-service changes.
10. After editing, run relevant tests and `vibeguard audit .` again before finishing.
11. Before creating a commit, run `vibeguard audit .`; before pushing or publishing, run `vibeguard audit . --strict`.
12. If execution evidence is available, run `vibeguard evidence .` before the final response and do not claim tests or audits ran unless they were observed.
13. Keep secrets server-side. Do not expose provider keys, database URLs, signing secrets, service-role keys, or webhook secrets to client code.
14. If the user pastes a secret in chat, treat it as exposed. Do not repeat it, put it in commands/logs/files/GitHub secrets/deployment settings/servers, or continue with deployment using that value. Guide the user to rotate it and enter a new value only through a local provider UI or secret-store prompt.
15. Keep VibeGuard scoped to guardrails. Do not clone, vendor, install, or link external playbooks or rule libraries unless the user explicitly asks for that separate setup.
16. Preserve existing repo-local instructions. Only update the managed VibeGuard block between the `vibeguard:start` and `vibeguard:end` markers.

Refresh this managed block only when `vibeguard audit .` reports stale guardrails, or manually with `vibeguard update .` / `npx --yes @taehwandev/vibeguard@latest update .`.
<!-- vibeguard:end -->
