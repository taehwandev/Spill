# Agent Briefs: Release Automation and Distribution Site

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside the assigned release automation and site scope.
- Keep the package script as the single source of bundle creation behavior.
- Signing and notarization must remain optional unless credentials are configured.

## Agent A: Product

Goal:

Define the release workflow and static download site behavior.

PRD authoring gate:

- Confirm `.agents/runs/release-automation-site/00-intake.md` has `Decision: build`.
- Confirm all clarifying questions are resolved.

Inputs:

- `.agents/specs/prd.md`
- `.agents/runs/release-automation-site/00-intake.md`

Output:

- `.agents/runs/release-automation-site/01-prd.md`

## Agent B: Architecture

Goal:

Keep release automation script-first and document how GitHub Actions, GitHub Releases, and GitHub Pages fit together.

Inputs:

- `.agents/runs/release-automation-site/01-prd.md`
- `.agents/specs/ard.md`
- `scripts/package-release.sh`

Output:

- `.agents/runs/release-automation-site/02-ard.md`
- `.agents/runs/release-automation-site/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Implement GitHub Release automation, GitHub Pages deployment, and the static download site.

Necessity gate:

- `00-intake.md` has a `build` decision.
- There are no unresolved clarifying questions.

Write scope:

- `.github/workflows/release.yml`
- `.github/workflows/pages.yml`
- `docs/`
- `README.md`
- `.agents/runs/release-automation-site/`

Do not edit:

- `Sources/Spill/`
- unrelated run artifacts

Acceptance:

- Release workflow builds with `scripts/package-release.sh`.
- Pages workflow deploys the static site.
- README explains unsigned and Developer ID release paths.

Final report:

- changed files
- behavior implemented
- commands run
- blockers

## Agent C2: Verifier

Goal:

Verify release artifacts still build locally and site assets are present.

Review scope:

- Workflow YAML
- static site links
- README release docs

Checks:

- PRD alignment
- ARD alignment
- package build
- workflow gates
- local site inspection

Final report:

- findings first
- verification result
- residual risks
