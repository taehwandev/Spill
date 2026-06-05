import Foundation

enum TokenMeteringGlobalSetup {
    static let setupPromptURL = "https://spill.thdev.app/token-metering/setup-prompt.md"
    static let runtimeInstructionURL = "https://spill.thdev.app/token-metering/runtime-instruction.md"
    static let workflowSetupPromptURL = "https://spill.thdev.app/token-metering/workflow-setup-prompt.md"

    static let globalPrompt = """
    # Spill Token Metering Setup Bootstrap

    MANDATORY ACTION: install or repair Spill token metering now.
    This is not just a policy note, not just documentation, and not just a global instruction to remember later.

    Use the current public setup request as the source of truth:
    https://spill.thdev.app/token-metering/setup-prompt.md

    You MUST run the public setup installer before doing anything else:
      /bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)"

    If shell, filesystem, sandbox, or user-level config permission is required, ask for that permission and then run the installer.
    The installer downloads the latest open-source Spill adapter files from spill.thdev.app, then installs and configures OpenAI/Codex, Claude Code, and Antigravity/AGY metering locally.
    The installer must install and repair OpenAI/Codex, Claude Code, and Antigravity/AGY together, regardless of which AI tool is currently handling this request.
    Codex is the OpenAI agent runtime hook; the OpenAI SDK adapter is also installed for direct OpenAI API/SDK usage.

    After the installer succeeds, fetch and apply the current runtime instruction as a global agent instruction:
    https://spill.thdev.app/token-metering/runtime-instruction.md

    Then ask only whether the user wants workflow-aware labels connected:
      Do you want Spill token usage to follow your workflow steps?

    Do not ask for a hook path in that first question.
    If the answer is yes, use the workflow-aware setup request as the source of truth:
    https://spill.thdev.app/token-metering/workflow-setup-prompt.md

    Do not save only the runtime instruction and call the task done.
    Do not give manual per-adapter setup steps as the primary answer.
    Do not claim Spill token metering is installed until the installer has run and these hook shapes have been verified:
    - OpenAI/Codex: ~/.codex/hooks.json has hooks.Stop[] with matcher: "" and a Spill Codex importer command. The direct OpenAI SDK adapter is installed under the Spill adapters directory.
    - Claude Code: ~/.claude/settings.json has hooks.Stop[] with matcher: "" and a Spill Claude hook command.
    - Antigravity/AGY: ~/.gemini/config/hooks.json has a "spill-metering" JSONHookSpec containing PostInvocation[] with matcher: "" and a Spill AGY hook command. Do not use a root-level PostInvocation array.

    The workflow setup request discovers candidate workflow scripts and config files. Script-based workflows take priority because they can write exact step labels before each AI step. It asks before edits, and only then passes a selected hook path to the public installer when needed:
      /bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)" -- --workflow-hook /path/to/.agents/hooks.json
    """

    static let workflowPrompt = """
    # Spill Token Metering Workflow Setup Bootstrap

    Use this only after the normal Spill token metering installer has succeeded.

    Use the current public workflow setup request as the source of truth:
    https://spill.thdev.app/token-metering/workflow-setup-prompt.md

    Ask only whether the user wants workflow-aware labels:
      Do you want Spill token usage to follow your workflow steps?

    Do not ask for a hook path in that first question. If the answer is no, do not modify workflow files.
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
    """
}
