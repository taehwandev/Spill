# Detailed PRD: Manual Update Check

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, `Clarity: clear`, and no blocking
questions.

## Summary

Add a manual update check that compares the bundled app version with a static
release manifest. The app should show current update status in Preferences,
surface Check for Updates from the app/status menus, and open the release
download URL when a newer version exists.

## Resolved Inputs

- maintainer decisions: add an update button and version check; avoid a custom
  server.
- repo-researched facts: GitHub Releases already expose stable latest download
  asset URLs; packaged app bundles include `CFBundleShortVersionString`;
  Preferences and menu bar menus already contain maintenance actions.
- assumptions: `update.json` is uploaded as a GitHub Release asset and fetched
  from the latest release URL.

## Goals

- Let users manually check whether Spill is current.
- Show an Update button only when a newer release is available.
- Generate release update metadata as part of the packaging/release path.
- Keep the check lightweight and explicit.

## Non-goals

- Automatic update installation.
- Background update polling.
- Sparkle appcast generation.
- Homebrew Cask update policy.

## User Stories

- As a user, I want to check for updates from the app without opening GitHub
  manually.
- As a maintainer, I want update metadata to be produced by the existing release
  process.

## UX Requirements

### Entry Point

Users find Check for Updates in Preferences, the app menu, and the status item
context menu.

### Layout

No compact panel UI changes. Preferences contains a compact update section with
current version, status, and action buttons.

### States

- loading: button is disabled and shows that the check is in progress.
- empty: before a check, Preferences shows the current installed version.
- unavailable: network, HTTP, or malformed manifest failures show a short error.
- permission required: none.
- success: up-to-date state says the current version is installed.
- failure: failed checks keep the user on the current installed version and allow
  retry.

## Functional Requirements

1. Add a static update manifest model with latest version, build, macOS minimum,
   download URL, release notes URL, and published timestamp.
2. Generate `update.json` during release packaging and upload it as a release
   asset.
3. Fetch the manifest only when the user clicks Check for Updates.
4. Compare dotted numeric versions with zero padding.
5. Show Update when manifest `latestVersion` is newer than the current bundle
   version.
6. Open the manifest download URL when the user clicks Update.
7. Treat unsupported macOS minimums as a non-installable available update state.

## Behavior Scenarios

### Update Available

Given the installed version is `2026.20.1` and the manifest latest version is
`2026.20.2`
When the user checks for updates
Then Preferences shows that `2026.20.2` is available and enables Update.

### Up To Date

Given the installed version is `2026.20.2` and the manifest latest version is
`2026.20.2`
When the user checks for updates
Then Preferences shows that Spill is up to date and does not show Update.

### Manifest Failure

Given the update manifest cannot be loaded or decoded
When the user checks for updates
Then Preferences shows a retryable failure message.

## Acceptance Criteria

- Preferences shows current version and update state.
- App menu and status item menu include Check for Updates.
- Release artifacts include `update.json`.
- Unit tests cover version comparison and manifest outcomes.
- `swift test` and workflow verification pass.

## Metrics

- perceived latency: manual check should complete within normal network latency.
- reliability: malformed manifests fail visibly and do not claim update success.
- resource use: no background polling or persistent network connection.

## Rollout

- MVP: manual manifest check and release asset generation.
- later: Sparkle with a signed appcast after Developer ID signing and
  notarization are ready.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.github/workflows/release.yml`
- `scripts/package-release.sh`
