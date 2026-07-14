import Foundation

enum TokenMeteringGlobalSetup {
    static let setupPromptURL = "https://spill.thdev.app/token-metering/setup-prompt.md"
    static let runtimeInstructionURL = "https://spill.thdev.app/token-metering/runtime-instruction.md"

    static let globalPrompt = """
    # Install Spill AI Token Metering

    Install or repair Spill token metering now with the one-step installer:

      /bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)"

    If shell, filesystem, sandbox, or user-level configuration permission is required, explain why and ask for that permission before running the command.

    Privacy boundary: Spill may read known local Codex/Claude JSONL session or transcript files and Antigravity/AGY metadata only to extract exact numeric token counts, timestamps, safe model ids, and opaque ids. It must never store or upload prompts, responses, commands, file paths, transcript text, logs, diffs, source content, environment values, or secrets.

    The installer handles Codex, Claude Code, and Antigravity/AGY together. It writes one shared instruction to `~/.spill/runtime-instruction.md` and adds only a small managed discovery bridge to each runtime's user instruction file. Preserve unrelated user instructions and existing workflow label hooks. Do not copy the full Spill prompt separately into Codex, Claude, or AGY files, and do not install AGY lifecycle hooks.

    After the installer finishes, report what it actually installed or repaired and note that already-running agent sessions may need to restart before the new shared instruction is loaded. Setup success is not proof that the current AI turn was recorded.

    Full setup contract: https://spill.thdev.app/token-metering/setup-prompt.md
    """
}
