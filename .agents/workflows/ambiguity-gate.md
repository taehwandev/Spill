# Ambiguity Gate

This protocol is shared by Claude, Codex, Gemini, and any other repo agent.
Use it before writing a PRD, ARD, task breakdown, or implementation plan.

Core rule:

Do not turn unknowns into silent assumptions.

## Inputs

Before classifying ambiguity, inspect:

- the user request;
- `.agents/specs/prd.md`;
- `.agents/specs/ard.md`;
- relevant existing code and run artifacts when the answer may already be in the repo.

Do not ask the maintainer for information that can be found in the repo or in the
current conversation.

## Unknown Classification

Classify each unknown as exactly one of these:

- `blocker`: The answer can change user-facing behavior, scope, architecture,
  permissions, privacy, data safety, distribution risk, or acceptance criteria.
- `researchable`: The answer should be found in repository docs, existing code,
  platform documentation, or current artifacts before asking the maintainer.
- `assumable`: The answer is a reversible implementation detail, aligns with
  existing project patterns, and does not change product meaning.
- `out-of-scope`: The request conflicts with current product direction or should
  be deferred/rejected.

Ask the maintainer only for `blocker` unknowns.

## Mandatory Blockers

Stop and ask when any of these are unclear:

- the user problem or intended outcome;
- what is in scope versus explicitly out of scope;
- visible UI behavior, entry point, or state model;
- empty, unavailable, permission-required, success, and failure behavior;
- data persistence, destructive changes, migrations, or rollback behavior;
- permissions, privacy, secrets, network access, private API use, or distribution impact;
- feasibility when the feature may depend on fragile OS behavior;
- acceptance criteria or verification strategy.

For Spill specifically, also stop when the request may expand the compact tray into
a large dashboard, depend on spacer behavior, or require private APIs.

## Grill-Me Question Pass

Before PRD authoring, run one focused question pass:

- Ask one to three questions by default.
- Ask up to five only when multiple high-risk blockers exist.
- Each question must name the decision being made and why it matters.
- Do not ask preference questions already settled by product docs, ARD, existing UI,
  or platform constraints.
- Batch questions once, then wait. Do not continue into PRD while blockers remain.

Required output shape when blocked:

```markdown
Decision: `needs-clarification`

Blocking unknowns:

- <category>: <why this blocks PRD/ARD/implementation>

Questions:

1. <decision question and consequence>
2. <decision question and consequence>

Safe assumptions:

- <only non-blocking assumptions, if any>
```

## Proceeding With Assumptions

If no blockers remain, record assumptions explicitly in `00-intake.md`.

Allowed assumption pattern:

```markdown
Assumption: <specific default>
Reason: <repo pattern, product rule, or reversible implementation detail>
Risk: <what would change if this assumption is wrong>
```

If the maintainer says to proceed with assumptions, choose the smallest reversible
option that matches the PRD/ARD and record it as an assumption.

## PRD Conversion

After blockers are resolved, convert behavior into testable PRD language:

- summarize maintainer answers and repo-researched facts;
- list assumptions separately from decisions;
- write behavior scenarios in `Given / When / Then` form;
- include normal, empty, unavailable, permission-required, success, and failure
  states when relevant;
- tie every scenario to acceptance criteria or verification.

Do not leave unresolved blockers in `Open Questions`. Open questions are allowed
only for non-blocking future follow-up.

## Shared Status Terms

All agents must use the same status terms:

- Necessity decision: `build`, `defer`, `reject`, `needs-clarification`.
- Ambiguity clarity: `clear`, `needs-clarification`.
- Resolution source: `maintainer`, `repo-research`, `assumption`.

If clarity is `needs-clarification`, stop before `01-prd.md`.
