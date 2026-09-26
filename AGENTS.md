<!-- BEGIN MANAGED TAO AGENT OS ROUTING -->
## Tao Agent OS Active Routing

This managed block is generated from `templates/repo-agents-routing.md` in the
shared Tao Agent OS. Everything outside this block is repo-owned.

Shared Tao Agent OS library:

```text
${TAO_HOME}/AGENTS.md
${TAO_HOME}/index.md
${TAO_HOME}/scripts/agent-entry.py
${TAO_HOME}/scripts/project-discover.py
<TAO_LAUNCHER>
```

Use repo-local instructions first. If this block is being installed into a
personal or global runtime instructions file, and the runtime starts outside the
target repo or the request does not name one clear repo, run
`agent-entry.py` or `project-discover.py` first and stop when it returns
`ambiguous` or `not_found`. If `agent-entry.py` returns `selected`, prefer
starting or relaunching the runtime with that selected repo as the primary
workspace. For Codex, use `codex -C <TARGET_REPO>`; add
`--add-dir ${TAO_HOME}` only when the task needs the shared
Tao Agent OS root in the session workspace. Repo instruction files define
behavior; runtime launch options define filesystem scope. Explicitly read the
current target project's
instruction file for this runtime before using Tao Agent OS: Codex-style
agents read `AGENTS.md`, Claude reads `CLAUDE.md` when
present, Codex-specific setups read `CODEX.md` when present,
Gemini/Antigravity/AGY reads `AGENTS.md`, and generic agents read their
configured project instruction document or `.agents/README.md` when used.
If the request names a product/workspace alias that may map to multiple repos,
use the local `~/.tao/projects.json` workspace group when available.
Do not guess a single repo from the alias alone. If work starts in one primary
repo and investigation shows a secondary repo must be written, stop before that
write and record a workspace scope checkpoint: starting primary, secondary or
source-of-truth repo, selected mode (`primary-led secondary read`,
`primary-led secondary write`, or `multi-session`), write scope, session model,
and cross-repo verification. When finish-check evidence is used and a secondary
repo was written, pass it as `workspace scope checkpoint=<evidence>`,
`scope expansion checkpoint=<evidence>`, or
`cross-repo scope checkpoint=<evidence>`.
Use the workflow router for narrow selection. Do not read `index.md` after
successful routing; it is a fallback catalog, not another startup requirement.
Do not create repo-local skill documents merely to copy shared Tao Agent OS
behavior. Keep repo-local skills, workflows, wiki pages, or runbooks only when
they contain product-specific facts, commands, domain policy, or verification
that cannot be shared safely.
VibeGuard is required before documentation, code, config, dependency, data,
deployment, or credential changes. In a tracked lifecycle the start and review
hooks run it with ${TAO_HOME} as the rule source and report `VibeGuard overall`;
read that line instead of repeating the audit, and run the package command
yourself only when a hook reports `Skipped`, when no tracked lifecycle is in
use, or as `--strict` before push or publish.
The VibeGuard site is a human reference and does not need to
be fetched by the agent. Do not run VibeGuard `setup` or `update` blindly. If
this repo already has custom agent instructions,
`.vibeguard.json`, `VIBEGUARD.md`, or a managed VibeGuard block, ask a short
application drill first: add pointer vs merge vs pin; audit-only vs refresh
with update vs first-time setup; apply now vs prepare instructions only.
Default to preserving current guardrails and running audit only unless the user
chooses to refresh the managed block.
Read-only lookup, explanation, status, and checks of a supplied diagnosis use
bounded direct evidence without start, fingerprint, mailbox, checkpoint, gate,
review, or finish calls. Applicable project instructions and source contracts
still apply. Checking a diagnosis is not a diff review merely because the user
says "verify". Explicit change/PR reviews and release acceptance retain their
review workflow. Enter the writable lifecycle before any authorized edit.
The lifecycle and gate requirements below apply only to tracked work, not these
read-only answers. When updating an installed routing block, replace its older
blanket multi-step requirements and check local adapters for contradictions;
preserve product-specific contracts, safety rules and metering integration.
For tracked multi-step tasks, run `<TAO_LAUNCHER> start` once with `--request
"<USER_REQUEST>"`; it runs workflow routing/preflight and reports the required
hooks for the route. Do not separately repeat workflow list, classify, route, or
preflight. Use the start output as the command manifest before selecting task
documents, editing, reviewing, committing, or reporting completion. If the
current user message is a direct question, answer it before routing or editing.
Do not wait for the user to name document keywords. Let routing/search infer
the work surface from the request, platform, concern, and touched files; use
`workflow-doc-surfaces.json` and the local document graph as inputs; read the
route's `required_docs` before editing or reviewing; and treat graph neighbors as
`reference_docs` unless the route promotes them to `required_docs`. If
routing/search misses a clearly relevant platform, concern, or document
surface, stop and report the gap instead of proceeding from memory. Reading the
selected `required_docs` is a direct agent responsibility; do not add a second
document-confirmation step.
After the start hook and required-doc reading, consume
`parallel_execution.delegation_policy`. When the runtime exposes workers and
the multi-agent collaboration skill identifies at least two meaningful slices
with disjoint scopes, a stable contract, an integration owner, and focused
verification, delegate automatically without waiting for explicit user
multi-agent wording. Use Codex native workers, Claude Agent/Task workers, or
the Gemini/AGY Antigravity agent runner according to the active runtime.
Otherwise record the concrete serial reason. At each parent-to-worker boundary,
run `<TAO_LAUNCHER> handoff`; it refreshes the provider-neutral, content-free
execution capsule and validates it once. A ready and valid handoff lets the
worker reuse the parent's route, preflight, and required-doc manifest and skip
duplicate startup. An invalid handoff is a successful fallback decision that
requires the worker's normal lifecycle; never reuse mismatched capsule state.
The parent is the sole gate-ledger owner. Workers use worker-specific evidence
paths, return scoped evidence, and never overwrite the parent ledger, including
after an invalid handoff fallback. For a Codex leaf, use `dispatch --execute`
only when isolation is explicitly required. A matching parent profile or
unavailable parent profile information both stay in the current process or use
a native worker; neither condition starts a fresh Codex process.
If the direct question asks how to start app, product, or feature work, answer
with the PRD -> ARD -> implementation path before lower-level coding steps. If
the work then proceeds into code, use the `product` route unless an existing
PRD/ARD or repo-local instruction makes the slice clearly trivial.
Documentation enforcement for the active tracked route is owned centrally by
the shared Tao Agent OS finish-check across all runtimes; this pointer does not
add a documentation gate or approval round to read-only answers.
Do not duplicate or restate these rules in repo-local files; keep only this
pointer. The source of truth and the exception process are
`${TAO_HOME}/workflows/skills/documentation-update/SKILL.md`; add
exceptions there rather than self-judging. Load that card when the active route
requires it or an unresolved documentation decision needs its contract.
If the workflow router or start hook cannot run, stop and report the blocker
before continuing. Keep its gate execution ledger current; each required gate
must have evidence before completion. Show a short gate signal after each
completed or failed gate or task step. Completion requires every required gate
to be 🐱🟢 SUCCESS. Use only two cat signal badges in human-visible reports:
🐱🟢 SUCCESS means executed with evidence, and 🐱🔴 FAIL means blocked, failed,
missed, or missing evidence and triggers missed-gate recovery: stop
finalization, preserve the first failed checkpoint, roll back only dependent
agent-made changes when safe, and run the retrospective workflow. Improve and
verify the owning Tao Agent OS doc, hook, validator, or test before resuming
that checkpoint. One repair cycle is allowed; stop on the same failure or an
unsafe or ambiguous repair. Do not report any third gate state.
When the wrapper scripts are available, keep the existing start evidence,
run `<TAO_LAUNCHER> review` after the scoped diff is ready, and run
`<TAO_LAUNCHER> finish` before final report, commit, release, or handoff. Pass
evidence for every route gate to the finish check. The wrappers write local
evidence under
`.tao/`; this directory is runtime evidence and should usually be
gitignored. When executing wrapper commands from an agent runtime, resolve
`${TAO_HOME}` to an absolute path first; do not leave `$HOME`,
`${HOME}`, `~`, or a relative path in the executable command. Missing wrapper
evidence or missing route gate evidence is
non-compliant even when the final files look correct. VibeGuard `Needs review`
must be reported explicitly and can pass the finish check only with an
`--allow-vibeguard-review` reason. `--request-classified` must include
`--classification-evidence` and is honored only for a delegated worker backed by
a ready and valid parent execution capsule; every other caller passes
`--request "<USER_REQUEST>"` and lets the classifier run. Work routes require
resolved-scope evidence such
as `clear-scoped`, `answered ... separate actionable`, or `blockers resolved`,
not weak markers such as `classified`, `done`, `clarified`, or `no blockers`.
If a request asks for Grill-Me or classification returns `grill_me: true`,
missing Grill-Me protocol or `/grilling` session evidence is 🐱🔴 FAIL and
requires missed-gate recovery.
Do not load every shared document by default.
Replace `${TAO_HOME}` with a portable root reference. In committed
repo-local instructions, use `${TAO_HOME}` for shared local installs
or a repo-relative pinned path such as `.agents/tao-agent-os`; do not commit a
personal absolute path such as `/Users/.../tao-agent-os`. Full local paths
belong only in shell environment setup, one-shot prompts, or uncommitted
user-level runtime bridges. Use legacy `${KEYFLOW_AGENT_ROOT}` only when the
environment already provides it.
Keep repo paths, commands, components, role matrices, and domain terms in this repo.
<!-- END MANAGED TAO AGENT OS ROUTING -->
<!-- BEGIN MANAGED TAO AGENT OS DOC ENFORCEMENT -->
Documentation requirements follow the active tracked route in shared Tao Agent OS.
Read-only answers do not create a documentation gate. Source of truth:
`${TAO_HOME}/workflows/skills/documentation-update/SKILL.md`.
<!-- END MANAGED TAO AGENT OS DOC ENFORCEMENT -->

# Agent Entry Point

Repo-local Spill instructions remain the source of truth for product direction,
paths, commands, release policy, and macOS-specific constraints. Agent workflow
guidance comes from the local Tao Agent OS checkout; do not keep repo-local
workflow overlays when a shared Tao Agent OS card covers the same behavior.

Shared Tao Agent OS library:

- Use the existing local checkout via `TAO_HOME`, falling back to the
  current local shared checkout when the variable is unset.
- Do not commit a personal absolute Tao Agent OS path into repo-local docs.
- For personal shared installs, set `TAO_HOME` in the runtime
  environment.
- For a future team-pinned install, use a repo-relative checkout such as
  `.agents/tao-agent-os` only after explicit approval.

```bash
TAO_ROOT="${TAO_HOME:-$HOME/git/tao-agent-os}"
```

- `${TAO_ROOT}/AGENTS.md`
- `${TAO_ROOT}/index.md`
- `${TAO_ROOT}/scripts/agent-hook.py`
- `${TAO_ROOT}/scripts/workflow.py`
- `${TAO_ROOT}/scripts/agent-preflight.py`
- `${TAO_ROOT}/scripts/agent-finish-check.py`

Use repo-local Spill instructions for product and command details. Use
Tao Agent OS for common, workflow, platform, and review cards. Load the
smallest relevant shared cards and link to them instead of copying shared
workflow guidance into this repo.

Runtime-specific routing labels:

- This `AGENTS.md` is the single project-root instruction entry point for Codex,
  Claude Code, and Antigravity/AGY. Do not add separate runtime-specific root
  docs when the same guidance can live here or in `.agents/`.
- When running Tao Agent OS workflow, preflight, or finish commands from
  Antigravity/AGY, use `SPILL_AI_TOOL=antigravity` or rely on the environment
  installed by Spill token metering setup. Use the current runtime tool label
  for other agents so safe workflow labels land in the correct label context.
- Antigravity/AGY uses the canonical `antigravity` tool label. `agy` is only an
  input alias.
- Antigravity/AGY context verification marker:
  `spill_antigravity_context_v1`.
- For Antigravity/AGY, at the very beginning of every user turn (after request classification and before running any other tools, edits, or commands), the agent MUST run the Spill setup helper command to write or refresh the short-lived label context:
  `node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-setup.mjs --label antigravity --task-type <task_type> --stage <stage> --if-absent`
  Ensure `<task_type>` and `<stage>` are derived from the user request classification.

Workflow and Spill artifact preservation:

- When editing, replacing, regenerating, or simplifying workflow, CI/CD,
  release, documentation publishing, hook, setup, install, or agent prompt
  files, preserve existing Spill-specific integration unless the user explicitly
  approves removal.
- Do not delete, disable, or overwrite Spill token-metering hooks, label handoff
  commands, `SPILL_AI_TOOL` / `SPILL_TOKEN_USAGE_AI_TOOL` environment handoff,
  setup helper references, adapter resources, docs publishing artifacts, install
  scripts, or workflow label calls just because a generic workflow template does
  not include them.
- If a workflow entry point, hook file, generated prompt, docs site, release
  script, or publishing path is renamed or replaced, carry the Spill
  responsibility forward in the same change. Update the matching Spill setup
  prompt, runtime instruction, installer, adapter resource, docs artifact, or
  verification path instead of dropping it.
- Removing a Spill workflow, docs, token-metering, installer, adapter, or
  publishing artifact requires explicit user approval, a documented replacement
  path, and verification that the replacement still preserves local metering and
  release/docs behavior.

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

- Follow the active Tao routing block above for stateless answers, tracked
  work, continuation, classification, evidence, and recovery.
- Preserve the existing Spill workflow label and metering integration.

Cross-surface settings impact:

- Before adding or changing a `SpillSettings` value, Preferences control, or
  user-visible configuration, record a settings impact map before implementation.
  The map must name the persistence owner and default/migration behavior, every
  reading process, the propagation transport, the refresh/invalidation trigger,
  the expected update latency, and every affected user surface.
- For AI-related settings, always inspect and explicitly mark `affected` or
  `not applicable` with a reason for all of these surfaces:
  1. Preferences.
  2. The main-process compact Spill Panel, which is the general dashboard surface.
  3. The separate `Spill - AI Token Metering` dashboard helper.
  4. The clock-adjacent AI glance in the menu bar status surface.
  5. Web dashboard, Private Usage Upload, sync payloads, or agent-facing summaries
     when the setting changes stored, synced, or remotely presented data.
- For non-AI settings, inspect every compact panel, dashboard, helper-app, and
  menu-bar surface that renders or filters the affected value. A Preferences-only
  implementation is incomplete when another visible surface consumes that state.
- Shared defaults persistence alone is not a real-time synchronization contract.
  When more than one process reads a setting, document and implement the explicit
  notification or IPC path, receiver reload/invalidation behavior, and whether the
  change must appear without restart, reopen, manual refresh, polling, or upload
  sync. Reuse the existing shared-defaults plus distributed-notification bridge
  when it fits; adding a polling loop requires an explicit ARD decision.
- PRD acceptance, ARD data flow, task ownership, tests, and manual verification
  must cover the writer, propagation path, and each affected surface. Verification
  must also prove that `not applicable` surfaces stay unaffected and that no
  duplicate timer, collector, network request, or sync path was introduced.

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
2. Read `.agents/specs/prd.md`, every applicable canonical domain PRD linked
   from that index, and `.agents/specs/ard.md`.
3. Follow the relevant Tao Agent OS workflow cards, starting from
   `${TAO_ROOT}/workflows/agent-task-lifecycle.md`.
4. Apply the shared Tao Agent OS ambiguity gate before PRD, ARD, task
   breakdown, implementation planning, or code work when scope or intent is
   unclear.
5. For safety-sensitive work, follow `VIBEGUARD.md`.

VibeGuard gate:

- Follow the active routing block for audit execution and reuse of observed hook results; preserve the managed VibeGuard safety rules below.
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
6. Ask before deleting data, running migrations, deploying to production, increasing paid API/model usage, adding recurring infrastructure, or changing credentials. For every real external production deployment, and any deployment whose target is unknown, immediately before execution state the exact target and action and wait for fresh user confirmation. Never infer, reuse, or bypass approval from earlier wording such as "deploy it" or "handle it yourself".
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
