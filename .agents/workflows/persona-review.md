# Persona Review Workflow

This workflow is a reusable review method for code, product behavior, UI, docs,
and release readiness. It is portable across projects: replace the product
constraints and verification commands with the target repository's equivalents.

Personas are review lenses, not fictional voices. Each persona should produce
concrete findings, risks, and verification gaps.

## When To Use

Use this workflow for:

- non-trivial code changes;
- UI or interaction changes;
- architecture or refactor changes;
- permission, privacy, packaging, or distribution changes;
- release candidates;
- ambiguous feature ideas that need structured critique before implementation.

For tiny mechanical edits, a single normal review is enough.

## Review Context Packet

Before starting, collect:

- user request or feature intent;
- changed files or diff summary;
- relevant PRD, ARD, task breakdown, or issue links;
- product constraints and non-goals;
- verification already run;
- known unresolved questions.

Do not ask the maintainer for information that can be found in the repository.
If a review cannot proceed without a blocking product decision, state that
clearly before inventing acceptance criteria.

## Persona Set

### 1. Product / Scope Reviewer

Focus:

- product fit;
- scope creep;
- user-facing value;
- consistency with current product direction;
- whether a feature is too large, too vague, or better handled elsewhere.

Primary question:

Does this change serve the product goal without broadening the surface area in a
way the product cannot sustain?

### 2. Native UX Reviewer

Focus:

- platform conventions;
- visual hierarchy;
- click targets;
- menu/context behavior;
- panel/window placement;
- motion and animation restraint;
- accessibility labels and discoverability.

Primary question:

Does this feel like a polished native experience for the target platform?

### 3. Power User Workflow Reviewer

Focus:

- speed of common workflows;
- keyboard and pointer ergonomics;
- repeated-use friction;
- fallback paths;
- whether advanced users can recover quickly from disabled or failed states.

Primary question:

Would a frequent user keep using this path after the novelty wears off?

### 4. Architecture / Maintainability Reviewer

Focus:

- module boundaries;
- ownership of state and side effects;
- coupling between UI, platform APIs, and domain logic;
- testability;
- migration safety;
- whether the change reduces or hides complexity.

Primary question:

Will the next related change be easier and safer because of this implementation?

### 5. Reliability / Performance Reviewer

Focus:

- polling and refresh cadence;
- async cancellation;
- resource use;
- timeout behavior;
- startup behavior;
- behavior under missing dependencies, unavailable APIs, or stale data.

Primary question:

Can this keep working quietly without wasting CPU, battery, memory, or user
attention?

### 6. Privacy / Permission / Distribution Reviewer

Focus:

- permissions;
- secret handling;
- user trust;
- private API risk;
- notarization or packaging risk;
- local-only versus network behavior;
- data persistence and rollback risk.

Primary question:

Does this preserve user trust and distribution viability?

### 7. QA / Regression Reviewer

Focus:

- edge cases;
- empty, loading, unavailable, permission-required, success, and failure states;
- automated test coverage;
- smoke/manual coverage;
- known regressions;
- missing acceptance checks.

Primary question:

What can still break, and how would we catch it before shipping?

## Default Review Order

Use this order unless the task suggests a better one:

1. Architecture / Maintainability
2. Native UX
3. Product / Scope
4. Reliability / Performance
5. Privacy / Permission / Distribution
6. Power User Workflow
7. QA / Regression

Rationale:

Start with structure, then user experience and product fit, then operational
risk, then verification.

## Output Format

Lead with findings. Do not hide findings behind a summary.

For each finding:

```text
Severity: Blocker | High | Medium | Low | Note
Persona: <reviewer name>
Location: <file:line, artifact section, or behavior area>
Issue: <what is wrong or risky>
Impact: <why it matters>
Recommendation: <specific change or decision>
Verification: <test, smoke, or manual check that should cover it>
```

After findings, include:

- cross-persona conflicts or tradeoffs;
- open questions;
- verification gaps;
- concise overall recommendation.

If there are no findings, say that clearly and list residual risks or missing
checks.

## Severity Guide

Blocker:

The change should not ship. It breaks core behavior, violates a hard product or
architecture rule, creates serious trust/distribution risk, or lacks a blocking
decision.

High:

The change can ship only after a fix or explicit maintainer acceptance. It
likely causes user-visible regression, data loss, permission confusion, or
unbounded maintenance cost.

Medium:

The change is directionally acceptable but has meaningful risk, missing tests,
or a workflow problem that should be fixed soon.

Low:

Polish, clarity, naming, minor coverage, or maintainability improvements.

Note:

Observation without required action.

## Execution Modes

### Single-Agent Review

Use one reviewer agent to run every persona sequentially. Keep sections concise
and avoid duplicating the same finding under multiple personas.

### Multi-Agent Review

Use separate reviewers only when the maintainer explicitly asks for delegated or
parallel agent work. Give each reviewer a bounded persona and ask for findings
only in that scope.

### Lightweight Review

For small changes, use only:

- Architecture / Maintainability;
- Product / Scope;
- QA / Regression.

### Release Review

For release candidates, use all seven personas and add any repository-specific
release checklist.

## Synthesis Rules

- Merge duplicate findings.
- Prefer concrete file/line or artifact references.
- If personas disagree, name the tradeoff instead of averaging it away.
- Do not expand scope silently; mark future ideas as follow-up.
- Tie recommendations to acceptance criteria or verification when possible.
- Keep optional polish separate from ship blockers.

## Reusable Prompt

```text
Review this change using the Persona Review Workflow.

Context:
- Intent:
- Changed files:
- Product constraints:
- Verification already run:
- Known risks:

Use these personas:
- Product / Scope
- Native UX
- Power User Workflow
- Architecture / Maintainability
- Reliability / Performance
- Privacy / Permission / Distribution
- QA / Regression

Lead with findings. For each finding include severity, persona, location, issue,
impact, recommendation, and verification. Then summarize tradeoffs, open
questions, verification gaps, and overall recommendation.
```
