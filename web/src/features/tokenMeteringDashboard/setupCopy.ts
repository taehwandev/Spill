export type CopiedTarget = "install" | "setup" | "workflow" | null;

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

Then ask whether the user uses a workflow runner or hook file. If they do, use the workflow-aware setup request as the source of truth:
https://spill.thdev.app/token-metering/workflow-setup-prompt.md

Do not save only the runtime instruction and call the task done.
Do not give manual per-adapter setup steps as the primary answer.
Do not claim Spill token metering is installed until the installer has run and OpenAI/Codex, Claude Code, and Antigravity/AGY setup has been verified.
For Antigravity/AGY, ~/.gemini/config/hooks.json must contain a "spill-metering" JSONHookSpec with PostInvocation[]; do not use a root-level PostInvocation array.`;

export const workflowSetupPrompt = `# Spill Token Metering Workflow Setup Bootstrap

Use this only after the normal Spill token metering installer has succeeded.

Use the current public workflow setup request as the source of truth:
https://spill.thdev.app/token-metering/workflow-setup-prompt.md

Ask the user whether they use a workflow runner or hook file that should label Spill token usage. If yes, ask for the workflow hook/config path and the reusable step names they want mapped. If no, do not modify workflow files.

When the user supplies a workflow path, ask before editing it. Wire each workflow step start to write a short-lived safe label context with:
  node ~/Library/Application\\ Support/Spill/adapters/setup/spill-token-metering-setup.mjs --label codex --task-type code_generation --stage implement

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
- workflow-install/hook-setup -> workflow_setup/implement`;
