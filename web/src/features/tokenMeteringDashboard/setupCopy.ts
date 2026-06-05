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
The installer must install and repair OpenAI/Codex, Claude Code, and Antigravity/AGY together, regardless of which AI tool is currently handling this request.
Codex is the OpenAI agent runtime hook; the OpenAI SDK adapter is also installed for direct OpenAI API/SDK usage.
After the installer succeeds, fetch and apply the current runtime instruction as a global agent instruction:
https://spill.thdev.app/token-metering/runtime-instruction.md

Then ask only whether the user wants workflow-aware labels connected:
  Do you want Spill token usage to follow your workflow steps?

Do not ask for a hook path in that first question.
If the answer is no, do not modify workflow files.
If the answer is yes, discover candidate workflow integration points yourself. Prefer script-based workflow entry points first, such as a local workflow runner script, task pipeline script, or clearly named agent workflow script. Use hook/config files only after script candidates are absent, or as a runtime hook receiver alongside the script when the tool requires it. If both a script and a hook/config file are present, wire labels in the script first. If one safe candidate is found, summarize it and ask before editing. If multiple candidates are found, ask the user which workflow should receive Spill labels. If no candidate is found, ask how their workflow is invoked or where its config lives.

After a workflow integration point is selected and editing is approved, wire each workflow step start to write a short-lived safe label context with:
  node ~/Library/Application\\ Support/Spill/adapters/setup/spill-token-metering-setup.mjs --label codex --task-type code_generation --stage implement

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
- review/risk-review -> code_review/verify
- docs/readme/guide -> documentation/draft
- changelog -> changelog/draft
- release-notes -> release_notes/draft
- commit -> git_commit/summarize
- pr/pull-request -> pull_request/summarize
- workflow-install/hook-setup -> workflow_setup/implement

Use safe reusable slugs only. Never encode project names, feature names, ticket ids, file names, branch names, user names, prompts, commands, diffs, logs, source content, or secrets.

If a selected hook/config integration point needs Spill's AGY hook merged into it, pass that selected path to the same public installer:
  /bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)" -- --workflow-hook /path/to/.agents/hooks.json

Do not save only the runtime instruction and call the task done.
Do not give manual per-adapter setup steps as the primary answer.
Do not claim Spill token metering is installed until these conditions are satisfied:
- The installer has run and OpenAI/Codex, Claude Code, and Antigravity/AGY setup has been verified.
- If workflow labels were requested, every workflow edit was approved by the user.
- If workflow labels were requested, script-based workflows were checked first and used when present.
- If workflow labels were requested, at least one workflow step can write a safe label context before the AI tool starts.
For Antigravity/AGY, ~/.gemini/config/hooks.json must contain a "spill-metering" JSONHookSpec with PostInvocation[]; do not use a root-level PostInvocation array.`;
