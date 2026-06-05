import Foundation

enum TokenMeteringGlobalSetup {
    static let setupPromptURL = "https://spill.thdev.app/token-metering/setup-prompt.md"
    static let runtimeInstructionURL = "https://spill.thdev.app/token-metering/runtime-instruction.md"

    static func prompt(allowsLocalDisplayNames: Bool) -> String {
        guard allowsLocalDisplayNames else {
            return globalPrompt
        }

        return globalPrompt + localDisplayNamesOptInBlock
    }

    static let globalPrompt = """
    # Spill Token Metering Setup Bootstrap

    MANDATORY ACTION: install or repair Spill token metering now.
    This is not just a policy note, not just documentation, and not just a global instruction to remember later.

    Use the current public setup request as the source of truth:
    https://spill.thdev.app/token-metering/setup-prompt.md

    You MUST run the public setup installer before doing anything else:
      /bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)"

    If shell, filesystem, sandbox, or user-level config permission is required, ask for that permission and then run the installer.
    The installer downloads the latest open-source Spill adapter files from spill.thdev.app, then installs and configures Codex, Claude Code, and Antigravity/AGY metering locally.
    The installer must install and repair Codex, Claude Code, and Antigravity/AGY together, regardless of which AI tool is currently handling this request.
    Codex is the OpenAI-backed agent runtime hook. Direct OpenAI SDK metering is optional and not part of the default agent dashboard.
    The installer must also configure supported runtime defaults: Claude Code uses SPILL_AI_TOOL=claude, Antigravity/AGY uses SPILL_AI_TOOL=antigravity, and Codex uses the codex tool label by default.
    The installer must narrowly allow Spill label handoff commands when the runtime supports permission allowlists. For Codex, write managed prefix_rule entries to ~/.codex/rules/default.rules. For Claude Code and Antigravity/AGY, write the same narrow commands to their user-level permission settings files. Do not use broad python3, node, or shell-wide allow rules. Do not make the user approve the same trusted Spill label command over and over after this explicit install request. Workflow runner permissions are separate from the default Spill metering install.

    After the installer succeeds, fetch and apply the current runtime instruction as a global agent instruction:
    https://spill.thdev.app/token-metering/runtime-instruction.md

    The runtime instruction must make every user-visible AI task write a safe per-turn label context when the setup helper exists. Workflow integration is only for better labels; it must not be required for recording usage. If no workflow exists, agents still classify the current task with safe reusable labels such as code_review/verify, review_response/implement, code_generation/implement, testing/verify, or uncategorized/summarize. Workflow-provided labels must win: agent per-turn fallback labels must use --if-absent, while workflow step labels must omit --if-absent so they can replace older fallback labels. Agents should always attempt the per-turn fallback label with --if-absent after request classification, even when workflow integration exists. The helper will skip the fallback when an active workflow label is already present, and will write the fallback when the workflow did not label that task.
    Do not configure agents or workflows to send conversation titles, work item titles, local aliases, task text, or display names. Usage events carry only safe reusable labels; Spill generates default work item names locally from ai_tool, task_type, stage, model id, and timestamp buckets.

    Then ask only whether the user wants workflow-aware labels connected:
      Do you want Spill token usage to follow your workflow steps?

    Do not ask for a hook path in that first question.
    If the answer is no, do not modify workflow files; installed hooks must still record usage when exact counts are available, and per-turn labels must still come from the runtime instruction.
    If the answer is yes, discover candidate workflow integration points yourself.

    Workflow integration rules:
    - Prefer script-based workflow entry points first, such as a local workflow runner script, task pipeline script, or clearly named agent workflow script.
    - Use hook/config files only after script candidates are absent, or as a runtime hook receiver alongside the script when the tool requires it.
    - If both a script and a hook/config file are present, wire labels in the script first. The hook/config file should only receive the adapter hook or fallback integration that the script cannot provide.
    - If one safe candidate is found, summarize the file you intend to edit and ask for approval before changing it.
    - If multiple candidates are found, ask the user which workflow should receive Spill labels.
    - If no candidate is found, ask how their workflow is invoked or where its config lives.

    After a workflow integration point is selected and editing is approved, wire each workflow step start to write a short-lived safe label context before the AI tool runs:
      node ~/Library/Application\\ Support/Spill/adapters/setup/spill-token-metering-setup.mjs --label <current-tool> --task-type code_generation --stage implement

    Do not add --if-absent to workflow step labels. --if-absent is only for the agent's per-turn fallback label when no workflow label already exists.
    Use the current runtime tool in --label. When invoking a workflow runner, set SPILL_AI_TOOL and SPILL_TOKEN_USAGE_AI_TOOL to the current runtime, or rely on the runtime-level env installed by the setup helper. Never let Claude Code or Antigravity/AGY workflow routing fall back to codex. Workflow runner permissions are separate from the default Spill metering install.

    For script workflows, add the label command before the script invokes the AI tool. If the script already has safe reusable step names, map those directly. For simple hook/config workflows without a script, wire the safest available step start hook; if it cannot run per step before the AI tool starts, treat it as receiver-only and do not claim detailed workflow labels are configured.

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
    - The installer has run and these hook shapes have been verified:
    - Codex: ~/.codex/hooks.json has hooks.Stop[] with matcher: "" and a Spill Codex importer command. ~/.codex/rules/default.rules has managed Spill prefix_rule entries for Spill Codex label handoff.
    - Claude Code: ~/.claude/settings.json has hooks.Stop[] with matcher: "", a Spill Claude hook command, SPILL_AI_TOOL=claude, and narrow allowlist entries for Spill label handoff.
    - Antigravity/AGY: ~/.gemini/config/hooks.json has a "spill-metering" JSONHookSpec containing PostInvocation[] with matcher: "" and a Spill AGY hook command. ~/.gemini/antigravity-cli/settings.json has SPILL_AI_TOOL=antigravity and narrow allowlist entries for Spill label handoff. Do not use a root-level PostInvocation array.
    - If workflow labels were requested, every workflow edit was approved by the user.
    - If workflow labels were requested, script-based workflows were checked first and used when present.
    - If workflow labels were requested, at least one workflow step can write a safe label context before the AI tool starts.

    If a selected hook/config integration point needs Spill's AGY hook merged into it, pass that selected path to the same public installer:
      /bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)" -- --workflow-hook /path/to/.agents/hooks.json
    """

    private static let localDisplayNamesOptInBlock = """

    # Optional Local Display Names Enabled

    The user enabled Spill's local display-name prompt option.
    After installing or repairing token metering, update the saved runtime instruction with this option.
    This option is not active until the user reapplies this copied prompt to the agent runtime.
    This prompt preference is separate from token usage data sync and must not be cloud-synced unless the user explicitly enables settings sync for this selected setting.

    You may attach a short local-only display alias when the runtime or workflow exposes a trusted reusable step name or when the user explicitly provides the alias.
    Do not derive display aliases from prompts, commands, transcripts, logs, files, repository names, branches, tickets, diffs, source content, environment values, or secrets.
    Do not send full commands or command text.
    Do not add display aliases to the usage event JSON body.
    Usage events must remain token-only and must still contain only the allowlisted usage-event keys.
    Local display aliases may be visible to the agent applying this prompt and may be stored only as local display metadata.
    """
}
