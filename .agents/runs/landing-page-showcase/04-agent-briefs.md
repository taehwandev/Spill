# Agent Briefs: Landing Page Showcase

## Coordinator Notes

- Keep all landing page source files buildable and clean.
- Do not revert changes outside the assigned scope of docs/index.html.
- Confirm the feature necessity decision before implementation.
- Do not introduce bloated external media dependencies.

## Agent A: Product

Goal:

Translate the landing page layout requirements into a testable scroll-snapped fullscreen showcase requirement.

Inputs:

- `.agents/runs/landing-page-showcase/00-intake.md`

Output:

- `.agents/runs/landing-page-showcase/01-prd.md`

## Agent B: Architecture

Goal:

Define the technical structure, layout choices, and JavaScript modules for the client-side simulators.

Inputs:

- `.agents/runs/landing-page-showcase/01-prd.md`

Output:

- `.agents/runs/landing-page-showcase/02-ard.md`
- `.agents/runs/landing-page-showcase/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Implement the responsive page-by-page layout with interactive simulators in `docs/index.html`.

Necessity gate:

- Confirm `.agents/runs/landing-page-showcase/00-intake.md` has a `build` decision.

Write scope:

- `docs/index.html`

Do not edit:

- `Sources/Spill/`

Acceptance:

- Landing page renders correctly with the interactive elements, including smooth snapping states and CPU wave fluctuations.
- The site remains responsive on mobile and desktop viewports.

Final report:

- changed files
- behavior implemented
- manual verification results

## Agent C2: Verifier

Goal:

Verify the landing page against all viewport breakpoints, check animations, and confirm workflow compliance.

Review scope:

- `docs/index.html`

Checks:

- PRD alignment
- ARD alignment
- build
- tests
- workflow gates
- responsive inspection (320px to 2560px)

Final report:

- findings first
- verification result
- residual risks
