import Foundation

enum TokenMeteringGlobalSetup {
    static let setupPromptURL = "https://spill.thdev.app/token-metering/setup-prompt.md"
    static let runtimeInstructionURL = "https://spill.thdev.app/token-metering/runtime-instruction.md"

    static let globalPrompt = """
    # Spill Token Metering Setup Bootstrap

    MANDATORY ACTION: install or repair Spill token metering now.
    This is not just a policy note, not just documentation, and not just a global instruction to remember later.

    Use the current public setup request as the source of truth:
    https://spill.thdev.app/token-metering/setup-prompt.md

    You MUST run the public setup installer before doing anything else:
      /bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)"

    If shell, filesystem, sandbox, or user-level config permission is required, ask for that permission and then run the installer.
    The installer downloads the latest open-source Spill adapter files from spill.thdev.app, then installs and configures Codex, Claude Code, and Antigravity/AGY hooks locally.

    After the installer succeeds, fetch and apply the current runtime instruction as a global agent instruction:
    https://spill.thdev.app/token-metering/runtime-instruction.md

    Do not save only the runtime instruction and call the task done.
    Do not give manual per-adapter setup steps as the primary answer.
    Do not claim Spill token metering is installed until the installer has run and these hook shapes have been verified:
    - Codex: ~/.codex/hooks.json has hooks.Stop[] with matcher: "" and a Spill Codex importer command.
    - Claude Code: ~/.claude/settings.json has hooks.Stop[] with matcher: "" and a Spill Claude hook command.
    - Antigravity/AGY: ~/.gemini/config/hooks.json has root-level PostInvocation[] with matcher: "" and a Spill AGY hook command. Do not nest AGY hooks under "spill-metering".

    If a workflow hook path is supplied, pass it to the public installer:
      /bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)" -- --workflow-hook /path/to/.agents/hooks.json
    """
}
