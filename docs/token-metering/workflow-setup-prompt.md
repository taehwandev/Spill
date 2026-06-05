# Spill Token Metering Workflow Setup Request

Use this after the normal Spill token metering installer has succeeded.
This request is for users who run AI work through a workflow runner, local
agent script, task pipeline, or project hook system.

First, ask only whether the user wants workflow-aware labels:

```text
Do you want Spill token usage to follow your workflow steps?
```

Do not ask for a hook path in this first question. If the answer is no or
`none`, do not modify workflow files. Keep the normal runtime instruction only.

If the answer is yes, discover candidate workflow integration points yourself:

- Prefer script-based workflow entry points first, such as a local workflow
  runner script, task pipeline script, or clearly named agent workflow script.
  Examples include `.agents/scripts/*`, `.agents/workflows/*` driver scripts,
  `workflow.py`, `workflow.sh`, `scripts/*workflow*`, or package/Make targets
  that actually orchestrate AI work.
- Use workflow hook/config files only after script candidates are absent, or as
  a runtime hook receiver alongside the script when the tool requires it. Common
  examples are `.agents/hooks.json` or other clearly named hook/config files.
- If both a script and a hook/config file are present, wire labels in the script
  first. The hook/config file should only receive the adapter hook or fallback
  integration that the script cannot provide.
- If one safe candidate is found, summarize the file you intend to edit and ask
  for approval before changing it.
- If multiple candidates are found, ask the user which workflow should receive
  Spill labels.
- If no candidate is found, ask how their workflow is invoked or where its
  config lives.

After a workflow integration point is selected and editing is approved, wire
each workflow step start to write a short-lived safe label context before the AI
tool runs:

```bash
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-setup.mjs \
  --label codex \
  --task-type code_generation \
  --stage implement
```

Use the current runtime tool in `--label`: `codex`, `claude`, `antigravity`, or
`openai`.

For script workflows, add the label command at the point where the reusable
workflow step is known, before the script invokes the AI tool. If the script
already has safe step names, map those directly. If it has a generic command
dispatcher, add a small mapping table from reusable step names to
`task_type/stage` pairs. Do not derive labels from prompts, commands, file
paths, branches, tickets, diffs, logs, source content, or secrets.

For simple hook/config workflows without a script, wire the safest available
step start hook to write the same label context. If the hook/config cannot run
per step before the AI tool starts, treat it as a receiver-only integration and
do not claim detailed workflow labels are configured.

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

If a selected hook/config integration point is an Antigravity/AGY hook file, or
if the workflow needs Spill's AGY hook merged into that selected file, pass it
to the public installer:

```bash
/bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)" -- --workflow-hook /path/to/.agents/hooks.json
```

Do not claim workflow-aware metering is configured until:

- the normal OpenAI/Codex, Claude Code, Antigravity/AGY setup is already
  installed;
- every workflow edit was approved by the user;
- script-based workflows were checked first and used when present;
- at least one workflow step can write a safe label context before the AI tool
  starts;
- the hook/config file keeps AGY `PostInvocation[]` under the `"spill-metering"`
  JSONHookSpec and does not create a root-level `PostInvocation` array.
