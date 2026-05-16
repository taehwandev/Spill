# Feature Intake

## Feature ID

`release-automation-site`

## Request

The maintainer wants GitHub-based release automation and a public distribution site. The release path should build packaged macOS artifacts, create a GitHub Release, and upload the distributable files. The site should provide a simple download entry point for users.

## User Problem

Spill can now create local `.zip` and `.dmg` artifacts, but publishing still requires manual steps. Users also need a stable place to download the current release without browsing build outputs.

## Necessity Assessment

- Necessary for current product direction: yes, packaging and direct distribution are explicit product goals.
- Better solved by Spill repo automation: yes, release artifacts must match the app build scripts.
- Small enough for current scope: yes, this is CI and static documentation, not app UI expansion.
- Private APIs or harmful permissions: no.
- If not built: releases remain manual and the app has no public download surface.

Decision: `build`

Reason: This completes the packaging path with GitHub Releases and a static GitHub Pages download site.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none.
- researchable: current package script, repository remote, distribution requirements.
- assumable: use GitHub Pages for the site; use tag names like `v2026.20.1`; support unsigned artifacts when Apple signing secrets are absent.
- out-of-scope: custom domain, Homebrew Cask, Sparkle auto-updates.

Resolved inputs:

- maintainer: configure release publishing on GitHub and build a distribution site.
- repo-research: `scripts/package-release.sh` already creates `.zip` and `.dmg`; PRD/ARD require GitHub Releases and Developer ID notarization support.
- assumption: GitHub Pages is the default site host and `taehwandev/Spill` is the public repository URL.

## Clarifying Questions

Questions: none

## Target User

Mac users who want to download Spill, and maintainers who need a repeatable release path.

## Proposed Product Shape

Maintainers push a version tag or run a workflow manually with a per-week release count. GitHub Actions builds the app, optionally signs and notarizes when secrets exist, uploads release artifacts, and publishes a static Pages site with stable download links.

## Constraints

- macOS/public API constraints: CI must run on a macOS runner.
- permission constraints: no new app runtime permissions.
- distribution constraints: public release without Gatekeeper warnings requires Developer ID credentials and notarization.
- performance constraints: release automation can be slower than local development but should remain deterministic.

## Non-goals

- Custom domain setup.
- Homebrew Cask publication.
- Sparkle update feeds.
- Replacing Apple Developer ID requirements.

## Open Questions

- None blocking.

## Decision

Status: `accepted`

Reason: The request is aligned with distribution requirements and can be implemented with reversible repo automation.
