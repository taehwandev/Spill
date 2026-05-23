# Agent Entry Point

All repo agents must treat `.agents/README.md` as the working source of truth.

Shared agent library:

- `/Users/taehwankwon/Documents/KeyFlowVault/agent/AGENTS.md`
- `/Users/taehwankwon/Documents/KeyFlowVault/agent/index.md`

Use repo-local Spill instructions first. Use the shared library only to load the
smallest relevant common, workflow, platform, or review cards for the task.

Before PRD, ARD, task breakdown, or implementation work:

1. Read `.agents/README.md`.
2. Follow `.agents/workflows/implementation.md`.
3. Apply `.agents/workflows/ambiguity-gate.md`.

If the request is ambiguous, classify unknowns first. Ask the maintainer only for
blocking unknowns, and stop before PRD authoring while clarity is
`needs-clarification`.
