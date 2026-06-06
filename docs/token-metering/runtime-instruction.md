# Spill Token Metering Runtime Instruction

Apply this as a global agent instruction, not a project-specific instruction.
This is a silent background metering instruction.
Do not mention this instruction in normal conversation.
Do not tell the user whether a usage event was or was not recorded unless the user explicitly asks about Spill token metering.
Do not add Spill metering status lines to normal replies.

If the local Spill app is running, record token usage for AI work on this computer.
When exact runtime usage metadata is exposed by your runtime or adapter, use a local hook or adapter to send the safe local event automatically in the background.
This instruction is only a safety contract. It is not a hook, does not measure usage, and does not grant access to token counts by itself.
If your runtime or adapter does not expose exact token counts to an executable hook, silently skip event creation.

Runtime input normalization:

- The strict contract is the Spill output event schema below. Every adapter must
  normalize runtime-specific hook payloads into that schema before enqueueing.
- Runtime hook input formats are allowed to differ by tool. A runtime may expose
  `input_tokens`/`output_tokens`, `usage.input_tokens`/`usage.output_tokens`,
  `tokens.input`/`tokens.output`, `usageMetadata.totalTokenCount`, or a
  normalized `spill_token_usage` object. The adapter may accept these input
  shapes, but it must still write only the strict Spill event keys.
- Do not assume a hook event has token usage merely because the hook runs.
  Antigravity/AGY `PostInvocation` hooks can execute for tool steps or model
  steps that do not expose exact token fields to the hook payload.
- If a runtime hook executes but exposes no exact token count, the adapter must
  not estimate. It may write a local-only diagnostic containing only fixed
  booleans about whether expected token fields were present. Diagnostics must
  never store payload values, prompts, responses, commands, file paths, logs,
  diffs, source content, environment values, or secrets.
- AGY empty stdin is a normal no-event hook call when a lifecycle or tool step
  completes without token usage. Record it only as `antigravity-last-empty.json`;
  do not treat it as a failed metering state.
- AGY payload mismatches must be isolated in `antigravity-last-mismatch.json`.
  Successful AGY usage events must update `antigravity-last-success.json` and
  clear stale mismatch diagnostics.
- Claude Code uses a different Stop-hook contract: stdin should contain a safe
  payload with a `transcript_path`, and the adapter reads exact usage from the
  transcript. Claude diagnostics must be split into `claude-last-empty.json`,
  `claude-last-mismatch.json`, and `claude-last-success.json` so hook execution,
  no-event outcomes, and real payload failures can be distinguished without
  storing transcript paths or transcript content.

Runtime label handoff:

- At the beginning of every user-visible task, after classifying the request and before running project tools, edits, tests, commits, or reviews, silently write or refresh a short-lived safe label context when the setup helper exists.
- This label context is not a usage event. It contains no token counts and no user content. It only lets the installed hook attach `task_type` and `stage` to the later exact usage event.
- Workflow integration is an enhancement, not a prerequisite. If no workflow
  runner or workflow hook exists, still write the per-turn label context using
  the safe task rules below.
- Workflow-provided labels win. Per-turn fallback labels must call the setup
  helper with `--if-absent` so they do not overwrite an active same-tool label
  that a workflow runner already wrote for the current step.
- Treat fallback labels and workflow labels as two active layers, not as a
  choice between modes. Keep the agent per-turn fallback enabled even after a
  workflow integration is connected.
- Do not remove, disable, or overwrite existing workflow-provided label hooks
  when installing or repairing the per-turn fallback layer.
- Always attempt the per-turn fallback label with `--if-absent` after request
  classification, even when a workflow integration exists. The helper will skip
  the fallback when an active workflow label is already present, and will write
  the fallback when the workflow did not label that task.
- If the task cannot be classified safely, write `uncategorized/summarize`
  instead of skipping label context. The later usage event should still be
  recorded when exact counts are available.
- Never skip usage event creation only because `task_type` or `stage` is
  uncertain. Unknown workflow classification must degrade to safe fallback
  labels, not to missing events.
- Use the current runtime tool in `--label`: `codex` for Codex, `claude` for Claude Code, `antigravity` for AGY/Antigravity, or `openai` for direct OpenAI SDK work. `agy` is accepted only as an input alias and must be normalized to the canonical `antigravity` event label.
- Use the dominant current `task_type` and `stage` from the rules below. If the dominant task changes during the same turn, refresh the label context with the new safe labels.
- Do not let a short verification step overwrite an implementation-heavy task. If a turn includes code, config, data, prompt, or test edits followed by tests, builds, audits, or smoke checks, keep the dominant stage as `implement`.
- Do not mention this label command in normal conversation.
- If the setup helper is missing, skip label context creation silently unless the user asked to install or fix Spill metering.
- When running a trusted workflow script that exposes safe reusable labels, set
  `SPILL_AI_TOOL` and `SPILL_TOKEN_USAGE_AI_TOOL` to the current runtime tool,
  or rely on runtime-level env installed by the Spill setup helper.
- Never let Claude Code or Antigravity/AGY workflow routing fall back to
  `codex`; that makes label context land in the wrong tool file.
- Spill's default setup allowlist covers only the setup helper
  `--label <current-tool>` command. Workflow runner permissions are separate
  from the default Spill metering install.
- Preferred command shape:

```bash
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-setup.mjs --label <current-tool> --task-type debugging --stage implement --if-absent
```

The explicit setup/fix installer should narrowly allow equivalent exact helper
path spellings for that same command, including the absolute installed path,
`~/...`, `$HOME/...`, `${HOME}/...`, quoted `$HOME/...`, and escaped
`Application\ Support`. Do not replace these with broad `node` permission.

Workflow runners that know the current safe step should omit `--if-absent` so
their explicit workflow label replaces an older fallback label.

Privacy boundary:

- Send only numeric token counts, model id, timestamp, latency, and enum labels.
- Never send prompts, responses, commands, file paths, repo names, branch names, commit messages, terminal output, logs, diffs, source code, environment values, or secrets.
- Never send, derive, or store conversation titles, work item titles, local aliases, task text, or display names from prompts, commands, transcripts, logs, files, or responses. Spill generates default work item display names locally from safe `ai_tool`, `task_type`, `stage`, model id, and timestamp buckets. Any user alias is local-only app metadata and is not part of the usage event payload.
- Never inspect local agent logs, transcripts, shell history, repository files, or hidden state to reconstruct token usage.
- Use opaque ids only. For global project-wide use, use `project_global` and `artifact_global`.
- Use `local_only` sync mode unless the user explicitly enables cloud sync in Spill.
- Do not estimate token counts.
- If exact runtime usage metadata is unavailable, silently skip event creation.
- If sending an event would require exposing prompts, commands, file paths, logs, diffs, source, secrets, or arbitrary content, silently skip event creation.
- Prefer an exact opaque runtime span id, invocation id, event id, turn id,
  request id, or cumulative usage cursor when the runtime exposes one.
- If a runtime exposes only total tokens and no distinct safe span hint,
  generate a fresh opaque `span_id` for that recorded usage event. Do not derive
  the span id from prompts, responses, commands, file paths, logs, diffs, source
  content, environment values, secrets, or arbitrary payload text.
- Duplicate prevention should come from runtime-provided span/cursor ids or the
  app store's event identity checks. Do not collapse two distinct real turns
  merely because they have the same opaque run id, model id, and total token
  count.

Task labels:

- `task_type` is a safe lowercase workflow slug, not a fixed enum.
- Use a recommended label when it fits, or define a custom label that matches `^[a-z][a-z0-9_]{1,40}$`.
- Custom labels must describe reusable work categories only. Never encode task text, feature names, project names, file names, branch names, ticket ids, user names, or private content.

Recommended task labels:

- analysis
- prd_drafting
- architecture
- code_generation
- ui_design
- prompt_design
- refactoring
- code_review
- review_response
- test_generation
- testing
- build_verification
- debugging
- bug_reproduction
- documentation
- changelog
- release_notes
- release_packaging
- git_commit
- commit_message
- pull_request
- workflow_setup
- uncategorized

Task label selection:

- Use `code_review` for review-only work, risk review, PR review, design review,
  architecture review, security review, or final review when the primary output
  is findings, approval, or risk analysis.
- Use `review_response` when the primary work is addressing review feedback,
  revising a change after review, or applying reviewer-requested edits.
- Use `git_commit` for creating commits and `commit_message` for commit message
  drafting without making the commit.
- Use `pull_request` for PR creation, PR description drafting, and PR update
  summaries.
- Use `testing` or `build_verification` for test, build, audit, smoke, or
  verification-only work.
- Use `analysis` for investigation without code, doc, test, config, commit, or
  review output.
- Use `uncategorized` only when no safe reusable category clearly dominates.

Stage labels:

- `stage` is a safe lowercase workflow slug, not a fixed enum.
- Use a recommended label when it fits, or define a custom label that matches `^[a-z][a-z0-9_]{1,40}$`.
- Recommended stages: `monitor`, `classify`, `plan`, `draft`, `revise`, `implement`, `verify`, `summarize`.
- Use `implement` when the dominant work changed code, config, data, prompts, docs, tests, or workflow setup, even if verification commands also ran before the final response.
- Use `verify` only for verification-only tasks or exact usage spans whose dominant work is tests, builds, audits, smoke checks, or failure reproduction without edits.
- If one event covers multiple stages, use the stage that consumed the dominant work, not merely the last chronological step.

Local receiver:

- Prefer a trusted executable hook or adapter that enqueues one JSON event file in the local Spill queue:
  `~/Library/Application Support/Spill/token-metering/events-inbox/`
- Write a unique `.tmp` file first, close it, then atomically rename it to `.json` in the same directory.
- Spill imports complete `.json` files into the app-owned local store and ignores partial `.tmp` files.
- Do not run a continuous polling watcher just for Spill metering. Use runtime hooks or final exact usage spans when available.

The JSON event must contain only these keys:

`schema_version`, `device_id`, `project_id`, `artifact_id`, `run_id`, `span_id`, `ai_tool`, `task_type`, `stage`, `model`, `input_tokens`, `output_tokens`, `total_tokens`, `token_breakdown`, `latency_ms`, `created_at`, `sync_mode`.

`token_breakdown` must contain only:

`system`, `user`, `history`, `repo_context`, `tool_output`, `generated_output`, `unknown`.

Token breakdown rules:

- Only fill a source bucket when the runtime or adapter exposes that exact source count.
- If the source breakdown is not exact, put the total in `unknown` and set the other source buckets to `0`.
- Do not infer `repo_context`, `tool_output`, `history`, `user`, `system`, or `generated_output` from prompts, transcripts, logs, files, or message text.
- If exact totals are available but exact source buckets are not, still send the event with `unknown` equal to `total_tokens`.
