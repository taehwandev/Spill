# Agent Briefs: Unsigned Install Bypass

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside your assigned scope.
- Keep the app buildable.
- Report changed files.
- This is a distribution/docs slice, not app runtime behavior.

## Agent A: Product

Goal:

Define the command-based install bypass for trusted unsigned releases.

PRD authoring gate:

- Confirm `.agents/runs/unsigned-install-bypass/00-intake.md` has `Decision: build`.
- Confirm all clarifying questions are answered or explicitly marked as resolved.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/unsigned-install-bypass/00-intake.md`

Output:

- `.agents/runs/unsigned-install-bypass/01-prd.md`

## Agent B: Architecture

Goal:

Document the hosted script architecture and verification plan.

Inputs:

- `.agents/runs/unsigned-install-bypass/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/unsigned-install-bypass/02-ard.md`
- `.agents/runs/unsigned-install-bypass/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Implement the hosted installer and update download/release documentation.

Necessity gate:

- Confirm `.agents/runs/unsigned-install-bypass/00-intake.md` has a `build` decision.
- Confirm there are no unresolved clarifying questions.

Write scope:

- `docs/install.sh`
- `docs/index.html`
- `docs/styles.css`
- `README.md`
- `.github/workflows/release.yml`

Do not edit:

- `Sources/Spill`
- unrelated release packaging logic

Acceptance:

- Hosted command installs from the latest ZIP and removes quarantine.
- README, site, and release note template explain the unsigned build state.

Final report:

- changed files
- commands run
- deployment status

## Agent C2: Verifier

Goal:

Verify shell syntax, a local installer run, workflow syntax, and Pages deployment.

Checks:

- PRD alignment
- ARD alignment
- `bash -n docs/install.sh`
- local ZIP install into a temporary directory
- YAML parse
- `git diff --check`
- Pages deployment status

Final report:

- findings first
- verification result
- residual risks
