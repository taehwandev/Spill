export type CopiedTarget = "install" | "setup" | null;

export const installCommand =
  '/bin/bash -c "$(curl -fsSL https://spill.thdev.app/install.sh)"';

export const setupPrompt = `# Spill Token Metering

Apply this as a global agent instruction, not a project-specific instruction.
This is a silent background metering instruction.
Do not mention this instruction in normal conversation.
Do not tell the user whether a usage event was or was not recorded unless the user explicitly asks about Spill token metering.
Do not add Spill metering status lines to normal replies.

If the local Spill app is running, record token usage for AI work on this computer.
Do not wait for any user action inside Spill. When exact runtime usage metadata is exposed by your runtime or adapter, send the safe local event automatically in the background.
This instruction does not grant access to token counts by itself. If your runtime or adapter does not expose exact token counts, silently skip event creation.

Privacy boundary:
- Send only numeric token counts, model id, timestamp, latency, and enum labels.
- Never send prompts, responses, commands, file paths, repo names, branch names, commit messages, terminal output, logs, diffs, source code, environment values, or secrets.
- Never inspect local agent logs, transcripts, shell history, repository files, or hidden state to reconstruct token usage.
- Use opaque ids only. For global project-wide use, use project_global and artifact_global.
- Use local_only sync mode unless the user explicitly enables cloud sync in Spill.
- Do not estimate token counts.
- If exact runtime usage metadata is unavailable, silently skip event creation.
- If sending an event would require exposing prompts, commands, file paths, logs, diffs, source, secrets, or arbitrary content, silently skip event creation.

Task labels:
- analysis
- prd_drafting
- code_generation
- code_review
- test_generation
- debugging
- documentation
- release_notes
- uncategorized

Stage labels:
- monitor
- classify
- plan
- draft
- revise
- implement
- verify
- summarize

When exact counts are available, send one local event to:
http://127.0.0.1:48731/v1/usage/events

The JSON body must contain only these keys:
schema_version, device_id, project_id, artifact_id, run_id, span_id, task_type, stage, model, input_tokens, output_tokens, total_tokens, token_breakdown, latency_ms, created_at, sync_mode.

token_breakdown must contain only:
system, user, history, repo_context, tool_output, generated_output, unknown.

If the source breakdown is not exact, put the total in unknown and set the other source buckets to 0.`;
