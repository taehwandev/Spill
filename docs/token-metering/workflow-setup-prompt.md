# Spill Token Metering Workflow Setup Request

Use this after the normal Spill token metering installer has succeeded.
This request is for users who run AI work through a workflow runner, local
agent script, task pipeline, or project hook system.

First, ask whether the user wants workflow-aware labels:

```text
Do you use a workflow runner or hook file that should label Spill token usage? If yes, provide the workflow hook/config path and the step names you want mapped. If not, say none.
```

If the answer is `none`, do not modify workflow files. Keep the normal runtime
instruction only.

If a workflow hook/config path is supplied, ask before editing that file. Then
wire the workflow so each step start writes a short-lived label context before
the AI tool runs:

```bash
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-setup.mjs \
  --label codex \
  --task-type code_generation \
  --stage implement
```

Use the current runtime tool in `--label`: `codex`, `claude`, `antigravity`, or
`openai`.

Map reusable workflow steps to safe labels only:

| Workflow step examples | task_type | stage |
| --- | --- | --- |
| intake, classify, route | analysis | classify |
| plan, design-plan, implementation-plan | analysis | plan |
| write-code, edit, implement, patch | code_generation | implement |
| refactor, cleanup | refactoring | implement |
| bugfix, reproduce-fix | debugging | implement |
| test-authoring, add-tests | test_generation | implement |
| test, build, audit, smoke | testing | verify |
| review, risk-review | code_review | verify |
| docs, readme, guide | documentation | draft |
| changelog | changelog | draft |
| release-notes | release_notes | draft |
| commit | git_commit | summarize |
| pr, pull-request | pull_request | summarize |
| workflow-install, hook-setup | workflow_setup | implement |

Custom labels are allowed only when they match `^[a-z][a-z0-9_]{1,40}$` and
describe reusable workflow categories. Never encode project names, feature
names, ticket ids, file names, branch names, user names, prompts, commands,
diffs, logs, source content, or secrets.

Prefer workflow-provided labels over agent-inferred labels. If the workflow
does not know the active AI tool, add a small wrapper per tool or let the agent
write the same safe label context at step start.

If the workflow has an Antigravity/AGY hook file that the user explicitly
selected, pass it to the public installer:

```bash
/bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)" -- --workflow-hook /path/to/.agents/hooks.json
```

Do not claim workflow-aware metering is configured until:

- the normal OpenAI/Codex, Claude Code, Antigravity/AGY setup is already
  installed;
- every workflow edit was approved by the user;
- at least one workflow step can write a safe label context;
- the hook/config file keeps AGY `PostInvocation[]` under the `"spill-metering"`
  JSONHookSpec and does not create a root-level `PostInvocation` array.
