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

Do not save only the runtime instruction and call the task done.
Do not give manual per-adapter setup steps as the primary answer.
Do not claim Spill token metering is installed until the installer has run and OpenAI/Codex, Claude Code, and Antigravity/AGY setup has been verified.
For Antigravity/AGY, ~/.gemini/config/hooks.json must contain a "spill-metering" JSONHookSpec with PostInvocation[]; do not use a root-level PostInvocation array.`;
