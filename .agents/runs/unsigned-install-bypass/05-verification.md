# Verification: Unsigned Install Bypass

## Build Checks

- [x] `bash -n docs/install.sh`
- [x] local installer run against a release ZIP with temporary install directory
- [x] workflow YAML parse
- [x] `git diff --check`
- [x] `.agents` workflow verify

## Manual Checks

- [x] Pages deploy succeeds.
- [x] Site returns HTTP 200.
- [x] Hosted install script returns HTTP 200.
- [x] Latest DMG link redirects to the current release.
- [x] Latest ZIP link redirects to the current release.
- [x] Current release notes include the install command.

## Feature Checks

- [x] Hosted installer downloads a ZIP by default.
- [x] Hosted installer supports local test overrides.
- [x] Hosted installer removes quarantine from the installed app.
- [x] Site and README explain the Trash prompt case.

## Regression Checks

- [x] No app runtime behavior changed.
- [x] DMG and ZIP direct download links remain available.
- [x] Developer ID notarization path remains documented.

## Notes

Pages deployment succeeded for the install bypass commit and for the later site
redesign commit. The deployed HTML includes the new design copy and hosted
installer command.

## Result

Status: `pass`

Reason: Local implementation checks, Pages deployment, release notes, and live
site checks pass.
