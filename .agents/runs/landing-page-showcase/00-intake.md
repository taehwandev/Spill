# Feature Intake: Landing Page Showcase

## Feature ID

`landing-page-showcase`

## Request

Modify the Spill landing page (`docs/index.html`) using the user's provided Tailwind CSS structure. Ensure the page operates as an ultra-premium, interactive page-by-page showcase optimized perfectly for both PC and mobile viewports. Integrate live CSS interactive mocks of Spill and Agent Cat rather than using static image placeholders, ensuring maximum visual engagement.

## User Problem

Static landing pages with generic templates fail to convey the dynamic feel of menu bar utilities and interactive AI agents. Standard layouts often look poorly proportioned or broken on mobile devices, and placeholder images feel cheap. By delivering a fully simulated interactive sandbox, users can test Spill's window snapping and status items right inside their browser before installing.

## Necessity Assessment

- Necessity: This feature is necessary for the current product direction to ensure the storefront is polished and represents version 2.0.
- Platform: It is best solved in the static web documentation folder.
- Scope: The web simulator is small and compact enough to showcase all items clearly.
- APIs: It uses standard public browser APIs and requires no native OS permissions.
- Risk: If we do not build it, the documentation site will look dated and miss the 2.0 aesthetic.

Decision: `build`

Reason: High-impact marketing and presentation upgrade that establishes Spill's premium desktop utility brand.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: None.
- researchable: Responsive breakpoint bounds for complex CSS mocks.
- assumable: TailwindCSS should be used inline and inside custom styles to ensure zero-dependency hosting.
- out-of-scope: Server-side database integration or actual user account telemetry in the web sandbox.

Resolved inputs:

- maintainer: None.
- repo-research: `docs/assets/spill-icon.png` is the only local asset, which should be used as the branding anchor.
- assumption: We will build fully client-side interactive simulators for both Spill and Agent Cat to completely replace static image placeholders.

## Target User

Prospective Spill users, developers, and open-source maintainers checking out Spill on macOS.

## Proposed Product Shape

A stunning, responsive, fullscreen scroll-snapped landing page featuring:
1. **Interactive macOS & Spill Simulator**: Toggle the Spill dropdown panel next to a simulated hardware notch and watch window snapping actions reflow simulated windows live.
2. **Dynamic Performance Hub**: Live fluctuating SVG CPU waveform graphs, real-time memory dials, and interactive widgets.
3. **Agent Cat Collab Hub**: Dark-themed cyberpunk terminal simulation with real-time rolling AI telemetry logs and provider stats.
4. **Clean-cut installation guides** and a terminal copy utility.
5. **Open Source GitHub promotion**.

## Constraints

- Mobile viewport support: Must resize gracefully with touch-friendly layout components.
- Zero server-side dependency: 100% client-side HTML/CSS/JS.

## Non-goals

- Implementing actual macOS-to-web telemetry bridge.
- Generating bloated media files.

## Decision

Status: `accepted`

Reason: Clear user-approved layout direction and alignment with Spill 2.0 branding.
