# Detailed PRD: Release Automation and Distribution Site

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, `Clarity: clear`, and no blocking questions.

## Summary

Add GitHub Actions automation that packages Spill for macOS, creates GitHub Releases, uploads `.zip` and `.dmg` artifacts, and publishes a static GitHub Pages site for downloading the latest release.

## Resolved Inputs

- maintainer decisions: use GitHub release distribution and create a download site.
- repo-researched facts: the package script already supports version metadata, signing identity, and optional notarization profile.
- assumptions: GitHub Pages hosts the site; release tags use `vISO-year.ISO-week.release-count`, such as `v2026.20.1`; stable asset aliases are uploaded for website links.

## Goals

- Create a repeatable GitHub Release workflow.
- Support ad-hoc unsigned local/test releases by default.
- Support Developer ID signing and notarization through GitHub Secrets.
- Publish a minimal download site through GitHub Pages.
- Keep release documentation explicit about Apple credential requirements.

## Non-goals

- Buying or configuring Apple Developer credentials.
- Custom domain setup.
- Homebrew Cask automation.
- Sparkle update feed generation.

## User Stories

- As a maintainer, I want to push `v2026.20.1` and get a GitHub Release with macOS artifacts.
- As a maintainer, I want notarization to happen automatically when signing secrets are configured.
- As a user, I want a simple page where I can download the latest `.dmg`.
- As a user, I want to understand that unsigned builds may show Gatekeeper warnings.

## UX Requirements

### Entry Point

Users reach the distribution site through GitHub Pages. The primary action downloads the latest `.dmg`.

### Layout

The site should use the app icon, a concise product headline, primary download links, install steps, and a release/source link.

### States

- loading: static site loads without client-side dependency.
- empty: if no release exists, the GitHub latest download link shows GitHub's not-found state.
- unavailable: release workflow failure is visible in GitHub Actions.
- permission required: notarization requires Apple Developer credentials configured as repository secrets.
- success: release assets are attached to GitHub Release and the site deploys.
- failure: release job fails before publishing incomplete artifacts.

## Functional Requirements

1. Add a release workflow triggered by `v*` tags and manual dispatch.
2. Derive `SPILL_VERSION` from the tag or from current UTC ISO year/week plus a manual release count.
3. Build artifacts with `scripts/package-release.sh`.
4. Upload versioned and stable `.zip` and `.dmg` files to GitHub Releases.
5. Optionally import Developer ID credentials and notarize when secrets are present.
6. Add a Pages workflow for `docs/`.
7. Add a static distribution site under `docs/`.
8. Update README release instructions.

## Behavior Scenarios

### Tag Release

Given a maintainer pushes `v2026.20.1`
When the release workflow runs
Then it builds Spill, packages `.zip` and `.dmg`, and creates or updates a GitHub Release for that tag.

### Manual Release

Given a maintainer starts the workflow with release count `1` during ISO week 20 of 2026
When the workflow runs
Then it targets release tag `v2026.20.1` and uploads the generated artifacts.

### Signed Release

Given Developer ID and notarization secrets are configured
When the release workflow packages Spill
Then the workflow signs with Developer ID, notarizes the app and DMG, and uploads the notarized artifacts.

### Unsigned Release

Given signing secrets are absent  
When the release workflow packages Spill  
Then it produces ad-hoc signed artifacts and clearly documents that Gatekeeper warnings may appear.

## Acceptance Criteria

- `.github/workflows/release.yml` exists and uses the existing package script.
- `.github/workflows/pages.yml` deploys `docs/` through GitHub Pages.
- `docs/index.html` provides latest release download links.
- README documents tag-based releases, manual releases, and required secrets.
- Existing local package verification still passes.

## Metrics

- perceived latency: site should render immediately as static HTML/CSS.
- reliability: release workflow should fail on packaging, signing, notarization, or upload errors.
- resource use: no runtime overhead in the app.

## Rollout

- MVP: GitHub Release workflow plus Pages site.
- later: Homebrew Cask, custom domain, signed update feed.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `scripts/package-release.sh`
