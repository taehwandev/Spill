# Multi-Agent Workflow

This workflow turns an idea into implementation through explicit A > B > C gates.

## Roles

### A. Product Agent

Owns:

- user problem
- feature boundaries
- user-facing behavior
- success criteria
- non-goals

Outputs:

- feature intake
- detailed PRD

Must not:

- prescribe low-level implementation unless it is product-critical
- expand scope beyond the compact tray direction

### B. Architecture Agent

Owns:

- module boundaries
- API choices
- permission model
- data models
- failure modes
- test strategy

Outputs:

- detailed ARD
- implementation constraints
- risk list

Must not:

- add private API dependencies
- accept behavior that cannot be verified

### C. Build Pair

Two cooperating workers:

- C1 Builder: implements the slice.
- C2 Verifier: reviews the patch, checks behavior, and fills verification notes.

Outputs:

- code changes
- verification notes
- review findings
- follow-up tasks

C1 and C2 may run in parallel only when write scopes are disjoint. If not, C1 implements first and C2 reviews after.

## Required Flow

Every non-trivial feature goes through:

```text
0. Intake
0.5 Necessity and Clarification
1. Detailed PRD
2. Detailed ARD
3. Task Breakdown
4. Agent Briefs
5. Implementation
6. Review
7. Verification
8. Merge/Closeout
```

## Run Folder

Each feature should have a run folder:

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

Use `templates/run-folder.md` as the index template.

## Gate 0: Intake

Input:

- user request
- current product docs
- known technical constraints

Exit criteria:

- feature name exists
- user value is clear
- out-of-scope items are listed
- owner can decide whether the feature belongs in Spill

## Gate 0.5: Necessity and Clarification

Input:

- intake
- current product direction
- known macOS constraints
- maintainer intent from the conversation
- `.agents/workflows/ambiguity-gate.md`

Required checks:

- Is this feature necessary for Spill's current direction?
- Is this better solved by Spill, macOS, or an existing dedicated app?
- Can the feature stay compact enough for the tray?
- Does the feature require private APIs, fragile behavior, or permissions that make distribution worse?
- What is the product cost of not building it?
- Which unknowns are blockers, researchable, assumable, or out of scope?
- Are all blocker unknowns resolved before PRD authoring?

Allowed outcomes:

- `build`: proceed to detailed PRD.
- `defer`: record why it should wait.
- `reject`: record why it does not belong in Spill.
- `needs-clarification`: ask the maintainer one to three concise questions before continuing.

Exit criteria:

- necessity decision is recorded;
- tradeoffs are explicit;
- maintainer questions are resolved when the decision is not obvious.

Hard stop:

- If the decision is `needs-clarification`, do not author the detailed PRD.
- If ambiguity clarity is `needs-clarification`, do not author the detailed PRD.
- Leave `01-prd.md`, `02-ard.md`, and `03-task-breakdown.yml` as drafts until the maintainer answers.
- After the maintainer answers, update `00-intake.md` first, then proceed to the PRD.

## Gate 1: Detailed PRD

Input:

- intake
- global PRD

Entry criteria:

- `00-intake.md` has `Decision: build`.
- Clarifying questions are empty or explicitly marked as resolved.
- Product intent and UI scope are clear enough to write testable acceptance criteria.

Exit criteria:

- user stories are concrete
- UI behavior is described
- behavior scenarios use `Given / When / Then` for the main path and relevant edge states
- acceptance criteria are testable
- non-goals are explicit
- success metrics exist

If PRD is not clear, do not start ARD.

## Gate 2: Detailed ARD

Input:

- detailed PRD
- global ARD
- current code structure

Exit criteria:

- modules/files to change are listed
- public APIs and permissions are identified
- failure modes are listed
- verification strategy is defined
- implementation can be split safely

If ARD requires private API or fragile spacer behavior, stop and revise product scope.

## Gate 3: Task Breakdown

Input:

- PRD
- ARD

Exit criteria:

- tasks are small vertical slices
- each task has acceptance checks
- write scopes are disjoint where parallel work is planned
- dependencies are explicit

Task states:

- `todo`
- `in_progress`
- `blocked`
- `review`
- `verified`
- `done`

## Gate 4: Agent Briefs

Each agent brief must include:

- task ID
- role
- goal
- files/modules owned
- files/modules forbidden
- acceptance checks
- verification commands
- expected final report shape

For code-edit workers, always state:

- "You are not alone in the codebase."
- "Do not revert changes outside your assigned scope."
- "List changed files in your final report."

## Gate 5: Implementation

C1 Builder rules:

- implement only assigned task
- keep code buildable
- do not silently broaden scope
- update task state

Parallel work rules:

- Split by disjoint files/modules.
- Do not assign two writers to the same file.
- Keep architecture-affecting changes serialized.

Good parallel splits:

- System provider implementation vs UI placeholder.
- AI provider implementation vs preferences copy.
- Window action engine vs status strip UI.

Bad parallel splits:

- two agents editing the same SwiftUI view;
- one agent changing data models while another relies on undefined model shape;
- broad refactors across the whole app.

## Gate 6: Review

C2 Verifier reviews:

- correctness
- user-facing regressions
- permission behavior
- missing failure states
- tests/manual checks
- adherence to PRD/ARD

For non-trivial changes, use `.agents/workflows/persona-review.md` to structure
the review across product, native UX, power-user workflow, architecture,
reliability, permission/distribution, and QA perspectives. If the persona review
is skipped, state why in verification or closeout notes.

Review output must lead with findings.

## Gate 7: Verification

Verification tiers:

1. Static/build:
   - `swift build`
2. App bundle:
   - `./scripts/build-app.sh`
   - `python3 .agents/scripts/workflow.py runtime-smoke`
3. Manual smoke:
   - launch app
   - open panel
   - check permission state
   - test relevant action
4. Integration:
   - AX permission on/off
   - multiple displays if relevant
   - missing AI tools if relevant

## Gate 8: Closeout

Closeout must include:

- what shipped
- what was verified
- what remains risky
- follow-up tasks
- docs updated

## Workflow Verification

Run:

```bash
python3 .agents/scripts/workflow.py verify
```

This checks that required docs/templates exist, run folders are complete, architectural code gates pass, and the app builds.

Run language checks separately when reviewing docs or comments:

```bash
python3 .agents/scripts/workflow.py language-gates
```

Repository docs, task artifacts, code comments, and scripts must be written in English.
