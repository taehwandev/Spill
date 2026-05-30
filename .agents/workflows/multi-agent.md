# Spill Multi-Agent Overlay

Use the shared AgentPlaybook multi-agent workflow first:

`${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/workflows/multi-agent-collaboration.md`

For PRD, ARD, and delivery gates, also use:

`${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/workflows/product-architecture-delivery.md`

This file keeps only Spill-specific routing.

## Spill Flow

For non-trivial feature work, use this repo-local sequence:

```text
intake -> Spill ambiguity overlay -> PRD -> ARD -> task breakdown -> agent briefs -> implementation -> review -> verification -> closeout
```

Run folders stay in this repo:

```text
.agents/runs/<feature-id>/
├─ 00-intake.md
├─ 01-prd.md
├─ 02-ard.md
├─ 03-task-breakdown.yml
├─ 04-agent-briefs.md
├─ 05-verification.md
└─ 06-closeout.md
```

Use `.agents/templates/` for run artifacts and `.agents/scripts/workflow.py`
for repo-local gates.

## Spill Constraints

- Product work must preserve the compact control tray direction.
- Architecture work must avoid private API use, private macOS frameworks, and
  fragile menu bar spacer behavior.
- Parallel builders may edit disjoint files only. Serialize shared model,
  provider contract, release config, signing, notarization, and update changes.
- Verification must use `.agents/workflows/implementation.md` to pick focused
  build, smoke, panel, status-click, or release checks.
