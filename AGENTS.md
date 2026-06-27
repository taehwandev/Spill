<!-- BEGIN MANAGED AGENTPLAYBOOK ROUTING -->
## AgentPlaybook Active Routing

This managed block is the active shared AgentPlaybook workflow link for this
repository. Keep repo-local instructions in this file as the source of truth for
project paths, commands, domain rules, and product policy. If an older
AgentPlaybook section appears elsewhere in this file, this managed block wins
for shared workflow routing while repo-specific rules still win for local facts.

Resolve the shared root before running shared scripts:

```bash
AGENTPLAYBOOK_ROOT="${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}"
```

Shared entrypoints:

```text
${AGENTPLAYBOOK_ROOT}/AGENTS.md
${AGENTPLAYBOOK_ROOT}/index.md
${AGENTPLAYBOOK_ROOT}/scripts/agent-entry.py
${AGENTPLAYBOOK_ROOT}/scripts/project-discover.py
${AGENTPLAYBOOK_ROOT}/scripts/agent-hook.py
${AGENTPLAYBOOK_ROOT}/scripts/workflow.py
${AGENTPLAYBOOK_ROOT}/scripts/agent-preflight.py
${AGENTPLAYBOOK_ROOT}/scripts/agent-finish-check.py
```

Before project work, read repo-local guidance first, then use AgentPlaybook only
to select the smallest relevant shared cards. Do not copy, vendor, or download a
second AgentPlaybook root unless the user explicitly approves after seeing the
existing root path. Do not commit personal absolute AgentPlaybook paths; use
`${AGENTPLAYBOOK_HOME}` for shared local installs or a repo-pinned root only
when the repo intentionally owns one.

For every multi-step task, run the start hook before selecting shared docs,
editing, reviewing, committing, or reporting completion:

```bash
python3 "${AGENTPLAYBOOK_ROOT}/scripts/agent-hook.py" start --project "$(pwd)" --rules "${AGENTPLAYBOOK_ROOT}" --command <command> --request "<USER_REQUEST>"
```

Use the returned route manifest as the task checklist. Run the review hook after
the scoped diff is ready, and run the finish hook before final report, commit,
release, or handoff. Pass evidence for every required route gate. Missing route,
preflight, review, finish, or gate evidence is non-compliant even when the final
files look correct.

Request intake is mandatory for requirement analysis and modifications, even
when the task does not create a PRD. Before editing, present a short alignment
checkpoint to the user when assumptions affect behavior, scope, safety, cost,
data, or external state: what is clear, what is uncertain or different between
user intent and agent interpretation, whether PRD/ARD is being created or
skipped, and the exact question or assumption that unblocks work. Skipping a PRD
is not permission to skip this checkpoint.

If the route, repo workflow, or user asks for Grill-Me, use the actual Grill-Me
skill/service/session as the question drill. Do not replace Grill-Me with ad hoc
internal questions. Record the Grill-Me or alignment evidence in the finish
check when the route requires it.

For code work, decide whether to use subagents only after the target project,
owned files, boundaries, forbidden files, and verification commands are clear.
Use subagents for separable research, review, or implementation streams; keep
small single-boundary changes in the main agent. Record the split decision in
the route gates when requested.

If a required gate or hook fails, do not finalize. Return to the first missed
gate only and retry that same scope once. If it fails again, run the shared
retrospective-learning workflow and record the durable lesson before handoff or
another attempt.

VibeGuard is required before documentation, code, configuration, dependency,
data, deployment, or credential changes and again before finishing. Run it with
the selected AgentPlaybook root as the rule source. Do not run VibeGuard `setup`
or `update` blindly; preserve existing guardrails unless the user explicitly
chooses a refresh/setup mode. Human-visible gate status must use only
`🐱🟢 SUCCESS` or `🐱🔴 FAIL`.
<!-- END MANAGED AGENTPLAYBOOK ROUTING -->

# Agent Entry Point

Repo-local Spill instructions remain the source of truth for product direction,
paths, commands, release policy, and macOS-specific constraints. Agent workflow
guidance comes from the local AgentPlaybook checkout; do not keep repo-local
workflow overlays when a shared AgentPlaybook card covers the same behavior.

Shared AgentPlaybook library:

- Use the existing local checkout via `AGENTPLAYBOOK_HOME`, falling back to the
  current local shared checkout when the variable is unset.
- Do not commit a personal absolute AgentPlaybook path into repo-local docs.
- For personal shared installs, set `AGENTPLAYBOOK_HOME` in the runtime
  environment.
- For a future team-pinned install, use a repo-relative checkout such as
  `.agents/AgentPlaybook` only after explicit approval.

```bash
AGENTPLAYBOOK_ROOT="${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}"
```

- `${AGENTPLAYBOOK_ROOT}/AGENTS.md`
- `${AGENTPLAYBOOK_ROOT}/index.md`
- `${AGENTPLAYBOOK_ROOT}/scripts/agent-hook.py`
- `${AGENTPLAYBOOK_ROOT}/scripts/workflow.py`
- `${AGENTPLAYBOOK_ROOT}/scripts/agent-preflight.py`
- `${AGENTPLAYBOOK_ROOT}/scripts/agent-finish-check.py`

Use repo-local Spill instructions for product and command details. Use
AgentPlaybook for common, workflow, platform, and review cards. Load the
smallest relevant shared cards and link to them instead of copying shared
workflow guidance into this repo.

Runtime-specific routing labels:

- This `AGENTS.md` is the single project-root instruction entry point for Codex,
  Claude Code, and Antigravity/AGY. Do not add separate runtime-specific root
  docs when the same guidance can live here or in `.agents/`.
- When running AgentPlaybook workflow, preflight, or finish commands from
  Antigravity/AGY, use `SPILL_AI_TOOL=antigravity` or rely on the environment
  installed by Spill token metering setup. Use the current runtime tool label
  for other agents so safe workflow labels land in the correct label context.
- Antigravity/AGY uses the canonical `antigravity` tool label. `agy` is only an
  input alias.
- Antigravity/AGY context verification marker:
  `spill_antigravity_context_v1`.

Explicit Spill local status commands:

- Treat a user request such as `spill`, `Spill status`, token usage status, or
  a local metering summary as an explicit request to run the read-only local
  stats helper for the current runtime.
- Codex command:
  `node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool codex`
- Claude Code command:
  `node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool claude`
- Antigravity/AGY command:
  `node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool antigravity`
- Answer with the full aggregate summary: total, input, output, event count,
  average event size, peak event size, workflow label coverage,
  model/task/stage breakdowns, token detail categories, and recent activity.
  Do not answer only with input/output totals. Treat `unknown` as unavailable
  detail attribution, not as a guessed input category.
- This helper is read-only and is not a usage event, hook, importer, label
  handoff, or proof that the current turn was recorded.

Runtime hook evidence and privacy:

- A Spill label handoff permission prompt, such as a setup helper `--label
  antigravity ... --if-absent` command, is not a usage hook and is not evidence
  that AGY `PostInvocation` or any lifecycle hook recorded tokens. It only
  writes safe task/stage context for a later exact usage event.
- Do not claim AGY token metering works from mock payload injection, unit tests,
  hook config shape, hook-load logs, hook command execution logs, label file
  writes, or permission prompts alone. Those are setup or adapter checks only.
- AGY usage metering is proved only by a real AGY runtime turn followed by
  concrete local side effects: `antigravity-last-success.json` for that real
  payload, a queued/imported `events-inbox` usage file, or a new
  `token_usage_events` row with `ai_tool = antigravity`.
- Do not force dummy tool calls, permission-list calls, or other hidden
  user-visible tool activity merely to make a runtime hook fire. Such calls are
  diagnostic only and require an explicit user-approved test plan.
- Do not infer `task_type`, `stage`, token counts, token breakdown, or aliases
  from prompts, commands, tool names, file paths, diffs, logs, source content,
  shell history, transcripts, or arbitrary payload values. Use trusted safe
  labels or degrade to `uncategorized/summarize`.
- Adding AGY Stop or lifecycle hooks is allowed only after the current AGY
  runtime exposes that hook shape and exact token usage fields to the hook.
  Registering another hook without exact usage payload evidence is not a fix.

Routing and executable evidence:

- For multi-step tasks, run
  `python3 "${AGENTPLAYBOOK_ROOT}/scripts/agent-hook.py" start --project "$(pwd)" --rules "${AGENTPLAYBOOK_ROOT}" --command <command> --request "<USER_REQUEST>"`
  before selecting shared docs, editing, reviewing, committing, or reporting
  completion. If the current request is a direct question, answer it first, then
  run the start hook with `--request-classified --classification-evidence
  "<evidence>"` and record that evidence.
- Use only two cat signal badges in human-visible reports: 🐱🟢 SUCCESS means
  executed with evidence, and 🐱🔴 FAIL means blocked, failed, missed, or
  missing evidence. 🐱🔴 FAIL triggers missed-gate recovery: stop finalization,
  roll back only dependent agent-made changes after the missed gate when safe,
  return to the first missed gate only, and run the retrospective workflow. The
  missed gate gets one recovery retry; do not restart the whole route. Do not
  report any third gate state.
- When the wrappers are available, run `agent-hook.py start` before editing,
  `agent-hook.py review` after the scoped diff is ready, and
  `agent-hook.py finish` before final report, commit, release, or handoff. Pass
  evidence for every required route gate.
- VibeGuard `Needs review` must be reported explicitly and can pass the finish
  check only with an `--allow-vibeguard-review` reason.
- `--request-classified` must include `--classification-evidence`; if a request
  asks for a question drill, missing drill evidence is 🐱🔴 FAIL and requires
  missed-gate recovery.
- Wrapper evidence under `.agentplaybook/` is local runtime evidence, not source.

Claude Code native active importer:

- The primary token metering path for Claude Code is the native Swift importer
  (`TokenUsageClaudeCodeImporter`) that reads `~/.claude/projects/**/*.jsonl`
  directly. The Python Stop hook is a secondary source; both must produce
  identical `span_id` values so dedup works across both.
- Before editing any file under
  `Sources/Spill/TokenMetering/Importers/ClaudeCode/`, read
  `.agents/design/claude-code-importer.md`. It defines the span_id formula,
  turn_index persistence rules, state migration contract, and discovery
  constraints that all agents must follow.
- Key invariants to never violate:
  - `span_id = "span-" + sha256(session_id:model:request_id:turn_index:timestamp:input:output)[:12]`
  - `turn_index` is persistent across cycles via `nextTurnIndexBySource` — never reset to 0 per cycle.
  - State keys use `sha256(sessionID)[:24]`, NOT file paths.
  - Discovery has no date lookback; the coordinator must NOT pass a short `since:` window.
  - Session ID regex is `^[0-9a-f-]{32,}$` (UUID format, not a loose alphanumeric pattern).
  - Legacy state files (missing `next_turn_index_by_source`) must return a fresh empty state.

Before PRD, ARD, task breakdown, or implementation work:

1. Read `.agents/README.md`.
2. Read `.agents/specs/prd.md` and `.agents/specs/ard.md`.
3. Follow the relevant AgentPlaybook workflow cards, starting from
   `${AGENTPLAYBOOK_ROOT}/workflows/agent-task-lifecycle.md`.
4. Apply the shared AgentPlaybook ambiguity gate before PRD, ARD, task
   breakdown, implementation planning, or code work when scope or intent is
   unclear.
5. For safety-sensitive work, follow `VIBEGUARD.md`.

VibeGuard gate:

- Run `npx --yes @taehwandev/vibeguard audit . --rules "${AGENTPLAYBOOK_ROOT}"` before and after documentation, code, config, dependency, data, deployment, or credential changes.
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
