# Feature Intake

## Feature ID

`unsigned-install-bypass`

## Request

Users can hit a macOS Gatekeeper quarantine block when opening the current
ad-hoc signed public build. The maintainer wants the same command-based bypass
used by another desktop app: a terminal path that installs Spill and removes the
quarantine attribute. The solution should make actual usage possible before
Developer ID signing and notarization are configured.

## User Problem

The app can be downloaded successfully but macOS may report it as damaged and
offer to move it to Trash. That makes the published release look broken even
though the artifact builds and verifies.

## Necessity Assessment

- Product fit: distribution is part of the current packaging phase.
- Better owner: full resolution requires Developer ID notarization, but a
  documented quarantine reset is appropriate for trusted test releases.
- Surface size: this is distribution support, not a tray UI feature.
- Platform risk: no private APIs are needed. It uses standard shell tools and the
  quarantine extended attribute.
- Cost of deferral: test users can keep hitting the Trash prompt and assume the
  release is unusable.

Decision: `build`

Reason: This is a minimal distribution fix for the current unsigned release
state and does not change app runtime behavior.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none.
- researchable: existing release site and README instructions.
- assumable: host the installer from GitHub Pages because the site already lives
  there; keep DMG/ZIP download buttons.
- out-of-scope: replacing Developer ID signing and notarization.

Resolved inputs:

- maintainer: provide a command-based bypass for the current Trash prompt.
- repo-research: `docs/` is deployed to Pages and release assets expose stable
  ZIP/DMG download names.
- assumption: a hosted installer command is acceptable because it mirrors the
  requested command-based workflow.

## PRD Authoring Gate

Decision is `build` and clarity is `clear`.

## Clarifying Questions

Questions:

- none.

## Target User

Early testers installing Spill directly from GitHub Releases or the download
site before Developer ID signing is configured.

## Proposed Product Shape

Show a terminal install command on the download site and in README. Host a small
installer script in `docs/` that downloads the latest ZIP, installs the app into
Applications, removes `com.apple.quarantine`, and opens Spill.

## Constraints

- macOS/public API constraints: use standard macOS command-line tools only.
- permission constraints: `sudo` may be required when writing to `/Applications`.
- distribution constraints: document that notarization remains the long-term fix.
- performance constraints: installer work is one-time and outside the app.

## Non-goals

- Hide the fact that current public builds are ad-hoc signed.
- Claim this replaces notarization.
- Change app runtime permissions.

## Open Questions

- none.

## Decision

Status: `accepted`

Reason: Minimal command-based install support unblocks trusted test installs.
