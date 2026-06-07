export type CopiedTarget = "install" | "setup" | null;

export const installCommand =
  '/bin/bash -c "$(curl -fsSL https://spill.thdev.app/install.sh)"';

export const tokenMeteringInstallCommand =
  '/bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)"';

export const setupPrompt = `# Spill Token Metering Setup Bootstrap

MANDATORY ACTION: install or repair Spill token metering now.
This is not just a policy note, not just documentation, and not just a global instruction to remember later.

Use the current public setup request as the source of truth:
https://spill.thdev.app/token-metering/setup-prompt.md

You MUST run the public setup installer before doing anything else:
  ${tokenMeteringInstallCommand}

If shell, filesystem, sandbox, or user-level config permission is required, ask for that permission and then run the installer.
The installer must install and repair Codex, Claude Code, and Antigravity/AGY together, regardless of which AI tool is currently handling this request.
Codex is the OpenAI-backed agent runtime hook. Direct OpenAI SDK metering is optional and not part of the default agent dashboard.
The installer must also configure supported runtime defaults: Claude Code uses SPILL_AI_TOOL=claude, Antigravity/AGY uses SPILL_AI_TOOL=antigravity, and Codex uses the codex tool label by default.
The installer must narrowly allow Spill label handoff commands and explicit user-requested read-only Spill status commands when the runtime supports permission allowlists. The Spill allowlist must include common safe path spellings for the same exact helper commands: absolute path, ~/..., $HOME/..., \${HOME}/..., quoted $HOME/..., and escaped Application\\ Support. For Codex, write managed prefix_rule entries to ~/.codex/rules/default.rules. For Claude Code and Antigravity/AGY, write the same narrow commands to their user-level permission settings files. Do not use broad python3, node, or shell-wide allow rules. Do not make the user approve the same trusted Spill label command over and over after this explicit install request. Workflow runner permissions are separate from the default Spill metering install.
The installer must install the read-only local usage stats helper at ~/Library/Application Support/Spill/adapters/setup/spill-token-metering-stats.mjs. When the user explicitly asks for \`spill\`, Spill status, token usage status, or local usage status, the agent should run node ~/Library/Application\\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool <current-tool> and answer with the full self-scoped aggregate summary: total, input, output, event count, average event size, peak event size, model/task/stage breakdowns, source buckets, and recent activity. The prompt must also include concrete status commands for every first-class runtime: node ~/Library/Application\\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool codex, node ~/Library/Application\\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool claude, and node ~/Library/Application\\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool antigravity. The stats helper is not a usage event, hook, importer, or label handoff. Do not run it in normal replies and do not inspect prompts, responses, commands, file paths, logs, diffs, source content, environment values, transcripts, shell history, or secrets to explain its output.
The adapters must force the strict Spill output event schema while accepting runtime-specific exact-count input shapes. For Antigravity/AGY, use the local active importer when AGY conversation metadata exposes exact numeric usage fields; the importer may extract only numeric counts, safe model ids, and opaque conversation/generation ids and must never store prompts, responses, commands, file paths, logs, diffs, source, environment values, secrets, raw database paths, or arbitrary transcript content. Do not install AGY PostInvocation, Stop, or lifecycle hooks for Spill metering. The setup helper must remove managed Spill AGY hook entries so hook command logs cannot be mistaken for real usage evidence. Claude Code uses a different Stop-hook contract: stdin should contain a transcript_path payload, and the adapter reads exact usage from the transcript. Claude diagnostics must be split into claude-last-empty.json, claude-last-mismatch.json, and claude-last-success.json. Mismatch diagnostics may include observed_safe_shape booleans only, never raw payload values. Diagnostics must never store transcript paths, transcript content, payload values, prompts, responses, commands, file paths, logs, diffs, source, environment values, secrets, run ids, or span ids.
After the installer succeeds, fetch and apply the current runtime instruction as a global agent instruction:
https://spill.thdev.app/token-metering/runtime-instruction.md

The runtime instruction must make every user-visible AI task write a safe per-turn label context when the setup helper exists. Workflow integration is only for better labels; it must not be required for recording usage. If no workflow exists, agents still classify the current task with safe reusable labels such as code_review/verify, review_response/implement, code_generation/implement, testing/verify, or uncategorized/summarize. Workflow-provided labels must win: agent per-turn fallback labels must use --if-absent, while workflow step labels must omit --if-absent so they can replace older fallback labels. This is a two-layer design, not a choice between modes: keep the agent fallback layer active and add workflow labels on top when the user chooses workflow-aware labels. The setup helper must preserve existing UserPromptSubmit or workflow label hooks; never remove a workflow label hook to force agent-only fallback. Agents should always attempt the per-turn fallback label with --if-absent after request classification, even when workflow integration exists. The helper will skip the fallback when an active workflow label is already present, and will write the fallback when the workflow did not label that task.
Do not configure agents or workflows to send conversation titles, work item titles, local aliases, task text, or display names. Usage events carry only safe reusable labels; Spill generates default work item names locally from ai_tool, task_type, stage, model id, and timestamp buckets.

Then ask only whether the user wants workflow-aware labels connected:
  Do you want Spill token usage to follow your workflow steps?

Do not ask for a hook path in that first question.
If the answer is no, do not modify workflow files; installed hooks must still record usage when exact counts are available, and per-turn labels must still come from the runtime instruction.
If the answer is yes, discover candidate workflow integration points yourself. Do not remove existing workflow label hooks during discovery, install, or repair. Prefer script-based workflow entry points first, such as a local workflow runner script, task pipeline script, or clearly named agent workflow script. Use hook/config files only after script candidates are absent, or as a runtime hook receiver alongside the script when the tool requires it. If both a script and a hook/config file are present, wire labels in the script first. Preserve unrelated hooks and existing workflow label hooks; merge new Spill integration with the existing workflow instead of replacing it. If one safe candidate is found, summarize it and ask before editing. If multiple candidates are found, ask the user which workflow should receive Spill labels. If no candidate is found, ask how their workflow is invoked or where its config lives.

After a workflow integration point is selected and editing is approved, wire each workflow step start to write a short-lived safe label context with:
  node ~/Library/Application\\ Support/Spill/adapters/setup/spill-token-metering-setup.mjs --label <current-tool> --task-type code_generation --stage implement

Do not add --if-absent to workflow step labels. --if-absent is only for the agent's per-turn fallback label when no workflow label already exists.
Use the current runtime tool in --label. If a workflow or user-facing command says agy, treat it as an input alias for the canonical antigravity event label. When invoking a workflow runner, set SPILL_AI_TOOL and SPILL_TOKEN_USAGE_AI_TOOL to the current runtime, or rely on the runtime-level env installed by the setup helper. Never let Claude Code or Antigravity/AGY workflow routing fall back to codex. Workflow runner permissions are separate from the default Spill metering install.

For script workflows, add the label command before the script invokes the AI tool. If the script already has safe reusable step names, map those directly. For simple hook/config workflows without a script, wire the safest available step start hook; if it cannot run per step before the AI tool starts, treat it as receiver-only and do not claim detailed workflow labels are configured.

Prefer workflow-provided labels over agent-inferred labels. Use safe reusable slugs only. Never encode project names, feature names, ticket ids, file names, branch names, user names, prompts, commands, diffs, logs, source content, or secrets.

Suggested mapping:
- intake/classify/route -> analysis/classify
- plan/design-plan -> analysis/plan
- write-code/edit/implement/patch -> code_generation/implement
- refactor/cleanup -> refactoring/implement
- bugfix/reproduce-fix -> debugging/implement
- test-authoring/add-tests -> test_generation/implement
- test/build/audit/smoke -> testing/verify
- review/code-review/risk-review/pr-review -> code_review/verify
- review-response/address-review-comments -> review_response/implement
- docs/readme/guide -> documentation/draft
- changelog -> changelog/draft
- release-notes -> release_notes/draft
- commit -> git_commit/summarize
- commit-message -> commit_message/draft
- pr/pull-request -> pull_request/summarize
- workflow-install/hook-setup -> workflow_setup/implement

Use safe reusable slugs only. Never encode project names, feature names, ticket ids, file names, branch names, user names, prompts, commands, diffs, logs, source content, secrets, conversation titles, work item titles, local aliases, task text, or display names.

Do not save only the runtime instruction and call the task done.
Do not give manual per-adapter setup steps as the primary answer.
Do not claim Spill token metering is installed until these conditions are satisfied:
- The installer has run and Codex, Claude Code, and Antigravity/AGY setup has been verified, including Codex prefix_rule entries, SPILL_AI_TOOL runtime defaults, and Spill label handoff allowlists where supported.
- For Antigravity/AGY, the local active importer is the collection path when exact numeric usage is present in AGY conversation metadata. The installer removes managed Spill AGY hook entries from ~/.gemini/config/hooks.json, ~/.gemini/hooks.json, and ~/.gemini/antigravity-cli/hooks.json. The AGY diagnostic file is antigravity-active-importer-last.json.
- If workflow labels were requested, every workflow edit was approved by the user.
- If workflow labels were requested, script-based workflows were checked first and used when present.
- If workflow labels were requested, at least one workflow step can write a safe label context before the AI tool starts.
For Antigravity/AGY, ~/.gemini hook files must not contain managed Spill PostInvocation entries.`;
