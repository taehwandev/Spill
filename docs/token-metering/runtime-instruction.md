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

Runtime label handoff:

- At the beginning of every user-visible task, after classifying the request and before running project tools, edits, tests, commits, or reviews, silently write or refresh a short-lived safe label context when the setup helper exists.
- This label context is not a usage event. It contains no token counts and no user content. It only lets the installed hook attach `task_type` and `stage` to the later exact usage event.
- Use the current runtime tool in `--label`: `codex` for Codex, `claude` for Claude Code, `antigravity` for AGY/Antigravity, or `openai` for direct OpenAI SDK work.
- Use the dominant current `task_type` and `stage` from the rules below. If the dominant task changes during the same turn, refresh the label context with the new safe labels.
- Do not mention this label command in normal conversation.
- If the setup helper is missing, skip label context creation silently unless the user asked to install or fix Spill metering.
- Preferred command shape:

```bash
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-setup.mjs --label codex --task-type debugging --stage implement
```

Privacy boundary:

- Send only numeric token counts, model id, timestamp, latency, and enum labels.
- Never send prompts, responses, commands, file paths, repo names, branch names, commit messages, terminal output, logs, diffs, source code, environment values, or secrets.
- Never inspect local agent logs, transcripts, shell history, repository files, or hidden state to reconstruct token usage.
- Use opaque ids only. For global project-wide use, use `project_global` and `artifact_global`.
- Use `local_only` sync mode unless the user explicitly enables cloud sync in Spill.
- Do not estimate token counts.
- If exact runtime usage metadata is unavailable, silently skip event creation.
- If sending an event would require exposing prompts, commands, file paths, logs, diffs, source, secrets, or arbitrary content, silently skip event creation.

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

Stage labels:

- `stage` is a safe lowercase workflow slug, not a fixed enum.
- Use a recommended label when it fits, or define a custom label that matches `^[a-z][a-z0-9_]{1,40}$`.
- Recommended stages: `monitor`, `classify`, `plan`, `draft`, `revise`, `implement`, `verify`, `summarize`.
- If one event covers multiple stages, use the latest completed dominant stage.

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
