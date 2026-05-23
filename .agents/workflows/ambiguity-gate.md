# Spill Ambiguity Gate Overlay

Use the shared AgentPlaybook ambiguity gate first:

`/Users/taehwankwon/Documents/KeyFlowVault/AgentPlaybook/workflows/ambiguity-gate.md`

This file adds only Spill-specific blockers.

## Required Repo Inputs

Before PRD, ARD, task breakdown, implementation planning, or code work, inspect:

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/README.md`
- relevant existing code, run artifacts, and current conversation context

Do not ask the maintainer for information that is already available in those
sources.

## Spill-Specific Blockers

Stop and ask when the request may:

- expand Spill from a compact control tray into a large dashboard;
- depend on giant `NSStatusItem` spacers or physical menu bar recovery promises;
- require private macOS frameworks or fragile OS behavior;
- change Accessibility, launch-at-login, signing, notarization, update, or
  release behavior;
- add network calls, paid service usage, telemetry, credential handling, or
  background polling that changes privacy, cost, or distribution risk;
- change visible panel/menu bar behavior without clear empty, unavailable,
  permission-required, success, and failure states.

Use the shared output shape from AgentPlaybook when clarity is
`needs-clarification`. If blocked, stop before writing `01-prd.md`, `02-ard.md`,
or implementation tasks.
