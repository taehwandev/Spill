# Feature Intake

## Feature ID

`<kebab-case-id>`

## Request

Summarize the user request in 3-5 sentences.

## User Problem

What pain does this solve?

## Necessity Assessment

Answer these before writing a detailed PRD:

- Is this feature necessary for current product direction?
- Is it better solved by Spill, macOS, or an existing dedicated app?
- Is it small enough for the compact tray?
- Does it require private APIs, fragile behavior, or permissions that harm distribution?
- What happens if we do not build it?

Decision: `build | defer | reject | needs-clarification`

Reason:

## Ambiguity Gate

Use `${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/workflows/ambiguity-gate.md` before PRD authoring.

Clarity: `clear | needs-clarification`

Unknown classification:

- blocker:
- researchable:
- assumable:
- out-of-scope:

Resolved inputs:

- maintainer:
- repo-research:
- assumption:

If clarity is `needs-clarification`, ask only the blocking questions below and stop before writing `01-prd.md`.

## PRD Authoring Gate

If any of the following are unclear, set the decision to `needs-clarification`, ask the maintainer, and stop before writing `01-prd.md`:

- user intent
- expected behavior
- feature value
- UI scope
- feasibility
- permission impact
- distribution impact

Only write the detailed PRD after the maintainer answers and this intake is updated with `Decision: build`.

## Clarifying Questions

Ask the maintainer before PRD authoring if any of these are unclear:

- user intent
- expected behavior
- feature value
- UI scope
- feasibility
- permission or distribution implications

Questions:

- 

## Target User

Who needs this?

## Proposed Product Shape

What should the user see or do?

## Constraints

- macOS/public API constraints:
- permission constraints:
- distribution constraints:
- performance constraints:

## Settings And Surface Impact

Complete this section when the feature adds or changes a setting, configuration,
visibility rule, filter, or display mode. For AI-related settings, every first-class
surface below must be classified before PRD authoring.

- setting/configuration owner:
- persistence, default, and migration impact:
- reading processes:
- propagation transport and refresh trigger:
- required update latency:

| Surface | `affected` / `not applicable` | Reason and expected behavior |
| --- | --- | --- |
| Preferences |  |  |
| Compact Spill Panel / general dashboard |  |  |
| Separate AI Token Metering dashboard helper |  |  |
| Clock-adjacent AI menu-bar glance |  |  |
| Web dashboard / upload / agent summary, when data crosses that boundary |  |  |

For non-AI settings, keep only the relevant rows but include every panel,
dashboard, helper-app, or menu-bar surface that renders or filters the value.

## Non-goals

- 

## Open Questions

- 

## Decision

Status: `accepted | rejected | needs-research`

Reason:
