# Agent Briefs: <Feature Name>

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.

## Agent A: Product

Goal:

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/<feature>/00-intake.md`

Output:

- `.agents/runs/<feature>/01-prd.md`

## Agent B: Architecture

Goal:

Inputs:

- `.agents/runs/<feature>/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/<feature>/02-ard.md`
- `.agents/runs/<feature>/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Write scope:

- 

Do not edit:

- 

Acceptance:

- 

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Review scope:

- 

Checks:

- PRD alignment
- ARD alignment
- build
- manual behavior
- permission states

Final report:

- findings first
- verification result
- residual risks
