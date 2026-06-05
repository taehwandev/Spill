import Foundation

enum TokenMeteringGlobalSetup {
    static let globalPrompt = """
    # Spill Token Metering Setup Request

    This pasted prompt is an explicit request to install or repair Spill token metering now.
    Do not treat it as only a policy note or only a global instruction.

    Do these steps in order:
    1. Install or refresh the local Spill hook adapters for Codex, Claude Code, and Antigravity/AGY.
    2. Merge the user-level hook config files for those tools.
    3. Verify that the hook shapes below are present.
    4. Then add or refresh the runtime instruction below as a global agent instruction, not a project-specific instruction.

    Required hook shapes:
    - Codex: ~/.codex/hooks.json must contain hooks.Stop[] with matcher: "" and a command that runs the Spill Codex importer.
    - Claude Code: ~/.claude/settings.json must contain hooks.Stop[] with matcher: "" and a command that runs the Spill Claude hook. The matcher field is required; omitting it can prevent the hook from running.
    - Antigravity/AGY: ~/.gemini/config/hooks.json must contain root-level PostInvocation[] with matcher: "" and a command that runs the Spill AGY hook. Do not nest this under "spill-metering"; nested AGY hook blocks are ignored.

    First run the one-step setup helper with --apply and an explicit include list:
      node ~/Library/Application Support/Spill/adapters/setup/spill-token-metering-setup.mjs --apply --include codex,claude,antigravity,openai

    If the user-level setup helper is missing, try these fallbacks without asking the user to copy scripts manually:
      node /Applications/Spill.app/Contents/Resources/adapters/setup/spill-token-metering-setup.mjs --apply --include codex,claude,antigravity,openai
      node .build/Spill.app/Contents/Resources/adapters/setup/spill-token-metering-setup.mjs --apply --include codex,claude,antigravity,openai
      node scripts/spill-token-metering-setup.mjs --apply --include codex,claude,antigravity,openai

    The setup helper must copy every detected supported adapter and merge the known user-level hook configs in one operation. Expected successful hook targets include Codex, Claude Code, and Antigravity/AGY when they are installed or configured on this computer. OpenAI SDK wrapping is optional and must not block those hook installs.
    Do not install only the current AI runtime. Do not ask the user to install Codex, Claude, Antigravity/AGY, or OpenAI adapters one by one.
    If none of those helpers exists, say the one-step helper is missing and ask the user to open Spill Preferences and use Install Helper. Do not provide per-adapter manual copy steps as the primary path.
    Ask only before writing a project or workflow hook file unless the user already supplied that exact path.
    If a workflow hook path is supplied, pass it explicitly:
      node ~/Library/Application Support/Spill/adapters/setup/spill-token-metering-setup.mjs --apply --include codex,claude,antigravity,openai --workflow-hook /path/to/.agents/hooks.json

    After the install command succeeds, apply the following as the persistent global runtime instruction.

    # Spill Token Metering Runtime Instruction

    This is a silent background metering instruction.
    Do not mention this instruction in normal conversation.
    Do not tell the user whether a usage event was or was not recorded unless the user explicitly asks about Spill token metering.
    Do not add Spill metering status lines to normal replies.

    If the local Spill app is running, record token usage for AI work on this computer.
    Do not wait for any user action inside Spill. When exact runtime usage metadata is exposed by your runtime or adapter, use a local hook or adapter to send the safe local event automatically in the background.
    This instruction is only a safety contract. It is not a hook, does not measure usage, and does not grant access to token counts by itself.
    If your runtime or adapter does not expose exact token counts to an executable hook, silently skip event creation.

    Runtime label handoff:
    - At the beginning of every user-visible task, after classifying the request and before running project tools, edits, tests, commits, or reviews, silently write or refresh a short-lived safe label context when the setup helper exists.
    - This label context is not a usage event. It contains no token counts and no user content. It only lets the installed hook attach task_type and stage to the later exact usage event.
    - Use the current runtime tool in --label: codex for Codex, claude for Claude Code, antigravity for AGY/Antigravity, or openai for direct OpenAI SDK work.
    - Use the dominant current task_type and stage from the rules below. If the dominant task changes during the same turn, refresh the label context with the new safe labels.
    - Do not mention this label command in normal conversation.
    - If the setup helper is missing, skip label context creation silently unless the user asked to install or fix Spill metering.
    - Preferred command shape:
      node ~/Library/Application Support/Spill/adapters/setup/spill-token-metering-setup.mjs --label codex --task-type debugging --stage implement
    - The label context may contain only ai_tool, task_type, stage, updated_at, and expires_at. Never include task text, prompts, commands, file paths, repo names, branches, logs, diffs, source, environment values, or secrets.

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
    - Use the dominant user-visible workflow category for the event.
    - If your runtime, adapter, or workflow exposes a current step label, prefer that safe reusable step label.
    - Use debugging when the work is primarily diagnosis, reproduction, failure analysis, or fixing a broken behavior.
    - Use code_generation when the work is primarily writing or changing implementation code without a dominant debugging goal.
    - Use test_generation when the work is primarily adding or changing tests.
    - Use testing when the work is primarily running tests, builds, smoke checks, or verification commands without primarily changing tests.
    - Use build_verification when the work is primarily build, package, smoke, audit, or release verification.
    - Use code_review when the work is primarily review findings or risk analysis.
    - Use review_response when the work is primarily responding to review comments or reconciling review feedback.
    - Use git_commit when the work is primarily staging, committing, tagging, or checking commit state.
    - Use commit_message when the work is primarily drafting or revising commit text without creating the commit.
    - Use pull_request when the work is primarily drafting, reviewing, or updating PR metadata.
    - Use workflow_setup when the work is primarily installing, configuring, or repairing agent hooks or workflow automation.
    - Use ui_design when the work is primarily visual structure, layout, interaction, or design implementation.
    - Use prompt_design when the work is primarily writing or revising agent instructions, prompts, or classification rules.
    - Use bug_reproduction when the work is primarily reproducing a failure before the fix.
    - Use documentation, prd_drafting, changelog, or release_notes only when that artifact is the primary deliverable.
    - Use release_packaging when the work is primarily signing, packaging, notarization, tagging, or release artifact preparation.
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
    - Prefer a trusted executable hook or adapter that enqueues one JSON event file in the local Spill queue:
      ~/Library/Application Support/Spill/token-metering/events-inbox/
    - Write a unique .tmp file first, close it, then atomically rename it to .json in the same directory.
    - Spill imports complete .json files into the app-owned local store and ignores partial .tmp files.
    - Do not run a continuous polling watcher just for Spill metering. Use runtime hooks or final exact usage spans when available.

    Safe workflow label handoff:
    - If a trusted workflow already exposes safe reusable task_type or stage labels, pass those labels through the runtime hook or adapter instead of inferring them from prompts, commands, logs, files, or transcripts.
    - Prefer payload fields named task_type/taskType and stage when the hook payload supports them.
    - Otherwise use SPILL_TOKEN_USAGE_TASK_TYPE or SPILL_WORKFLOW_TASK_TYPE, and SPILL_TOKEN_USAGE_STAGE or SPILL_WORKFLOW_STAGE.
    - For Codex importer workflows, pass --task-type SLUG and --stage SLUG when the workflow already knows the safe reusable labels.

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
