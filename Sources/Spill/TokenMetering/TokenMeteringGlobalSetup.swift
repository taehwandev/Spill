import Foundation

enum TokenMeteringGlobalSetup {
    static let runtimeInstructionURL = "https://spill.thdev.app/token-metering/runtime-instruction.md"

    static let workflowPrompt = """
    # Connect Spill to This Workflow

    Treat the current directory as the workflow root. If it is not the directory that owns this workflow's instructions, hooks, or runner, stop and ask the user to run this prompt from the correct directory.

    Spill's basic in-app install already records exact token totals without classifying work type or stage. This workflow setup is optional and adds trusted reusable `task_type` and `stage` labels.

    Privacy boundary: Spill may read known local usage metadata only to extract exact numeric token counts, timestamps, safe model ids, and opaque ids. It never stores or uploads prompts, responses, commands, file paths, logs, diffs, source content, environment values, or secrets.

    After installing or repairing connection files, start a new session or restart any AI tool session that was already running so it loads the updated connection.

    1. Inspect only this workflow root for existing instruction files, hooks, runners, or reusable step definitions. Do not scan unrelated directories.
    2. If Spill metering is missing, install or repair it with:

       /bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)"

    3. At trusted workflow step boundaries, call the installed helper with the current runtime and safe reusable labels:

       node "$HOME/Library/Application Support/Spill/adapters/setup/spill-token-metering-setup.mjs" --label <codex|claude|antigravity> --task-type <safe_slug> --stage <safe_slug>

    Workflow labels must come from trusted workflow metadata, never prompts, commands, file paths, logs, diffs, source content, or transcripts. Preserve existing workflow hooks and instructions, and do not install AGY lifecycle hooks. Report the files changed and the checks performed.
    """
}
