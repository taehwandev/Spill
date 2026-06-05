import Foundation

enum TokenMeteringGlobalSetup {
    static let globalPrompt = """
    # Spill Token Metering

    Apply this as a global agent instruction, not a project-specific instruction.
    This is a silent background metering instruction.
    Do not mention this instruction in normal conversation.
    Do not tell the user whether a usage event was or was not recorded unless the user explicitly asks about Spill token metering.
    Do not add Spill metering status lines to normal replies.

    If the local Spill app is running, record token usage for AI work on this computer.
    Do not wait for any user action inside Spill. When exact runtime usage metadata is exposed by your runtime or adapter, use a local hook or adapter to send the safe local event automatically in the background.
    This instruction is only a safety contract. It is not a hook, does not measure usage, and does not grant access to token counts by itself.
    If your runtime or adapter does not expose exact token counts to an executable hook, silently skip event creation.

    Event timing:
    - Send at most one event for each assistant response or adapter span that exposes final exact token counts.
    - Prefer the final response event for the user-visible assistant turn. Do not also send separate events for every tool call unless your runtime exposes those tool calls as separate exact usage spans with their own token counts.
    - Do not send partial, streaming, retry, or duplicate events when a later final exact count for the same span will be available.
    - If the selected local receiver is unavailable, skip the event silently. Do not retry in a way that delays the response.

    ID rules:
    - Treat one user-requested task or conversation turn as a run when no runtime run id is exposed.
    - Reuse the runtime/adaptor run id when it is already opaque and safe; otherwise generate an opaque run_id.
    - Generate a new opaque span_id for each event. Do not encode project names, file paths, commands, prompts, branches, or task text in ids.
    - Use device_local when no opaque device id is exposed.

    AI tool labels:
    - ai_tool must be one of: codex, claude, antigravity, openai, unknown.
    - Use codex for Codex runtimes, claude for Claude runtimes, antigravity for AGY/Antigravity, and openai for direct OpenAI API/SDK usage.
    - Use unknown when the runtime or adapter cannot safely identify the tool without inspecting prompts, commands, files, logs, or private state.

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
    - task_type is a safe lowercase workflow slug, not a fixed enum.
    - Use a recommended label when it fits, or define a custom label that matches ^[a-z][a-z0-9_]{1,40}$.
    - Custom labels must describe reusable work categories only. Never encode task text, feature names, project names, file names, branch names, ticket ids, user names, or private content.

    Recommended task labels:
    - analysis
    - prd_drafting
    - architecture
    - code_generation
    - refactoring
    - code_review
    - test_generation
    - testing
    - debugging
    - documentation
    - release_notes
    - uncategorized

    Task label selection:
    - Use the dominant user-visible workflow category for the event.
    - If your runtime, adapter, or workflow exposes a current step label, prefer that safe reusable step label.
    - Use debugging when the work is primarily diagnosis, reproduction, failure analysis, or fixing a broken behavior.
    - Use code_generation when the work is primarily writing or changing implementation code without a dominant debugging goal.
    - Use test_generation when the work is primarily adding or changing tests.
    - Use testing when the work is primarily running tests, builds, smoke checks, or verification commands without primarily changing tests.
    - Use code_review when the work is primarily review findings or risk analysis.
    - Use documentation, prd_drafting, or release_notes only when that artifact is the primary deliverable.
    - Use analysis for answer-only reasoning or investigation without code/doc/test changes.
    - Use uncategorized when no label clearly dominates.

    Stage labels:
    - stage is a safe lowercase workflow slug, not a fixed enum.
    - Use a recommended label when it fits, or define a custom label that matches ^[a-z][a-z0-9_]{1,40}$.
    - Custom stage labels must describe reusable workflow phases only. Never encode task text, feature names, project names, file names, branch names, ticket ids, user names, or private content.

    Recommended stage labels:
    - monitor
    - classify
    - plan
    - draft
    - revise
    - implement
    - verify
    - summarize

    Stage label selection:
    - If your runtime, adapter, or workflow exposes a current step or phase label, prefer that safe reusable phase label.
    - Use classify for request classification or routing.
    - Use plan for implementation planning before edits.
    - Use implement for code, config, or data changes.
    - Use verify for tests, builds, audits, or smoke checks.
    - Use summarize for final answer or handoff.
    - Use draft for first-pass PRD/docs/release text and revise for later edits.
    - Use monitor for background-only observation.
    - If one event covers multiple stages, use the latest completed dominant stage.

    Local receiver:
    - Prefer a trusted executable hook or adapter that appends one JSON line to the local Spill inbox:
      ~/Library/Application Support/Spill/token-metering/events-inbox.jsonl
    - If the user explicitly enables Spill's loopback HTTP bridge, the same event may be sent to:
      http://127.0.0.1:48731/v1/usage/events
    - Do not run a continuous polling watcher just for Spill metering. Use runtime hooks or final exact usage spans when available.

    The JSON event must contain only these keys:
    schema_version, device_id, project_id, artifact_id, run_id, span_id, ai_tool, task_type, stage, model, input_tokens, output_tokens, total_tokens, token_breakdown, latency_ms, created_at, sync_mode.

    token_breakdown must contain only:
    system, user, history, repo_context, tool_output, generated_output, unknown.

    token_breakdown rules:
    - Only fill a source bucket when the runtime or adapter exposes that exact source count.
    - If the source breakdown is not exact, put the total in unknown and set the other source buckets to 0.
    - Do not infer repo_context, tool_output, history, user, system, or generated_output from prompts, transcripts, logs, files, or message text.
    - If exact totals are available but exact source buckets are not, still send the event with unknown equal to total_tokens.
    """
}
