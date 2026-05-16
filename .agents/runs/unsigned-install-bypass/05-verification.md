# Verification: Unsigned Install Bypass

## Build Checks

- [x] `bash -n docs/install.sh`
- [x] local installer run against a release ZIP with temporary install directory
- [x] workflow YAML parse
- [x] `git diff --check`
- [x] `.agents` workflow verify

## Manual Checks

- [ ] Pages deploy succeeds.
- [ ] Site returns HTTP 200.
- [ ] Latest DMG link redirects to the current release.
- [ ] Latest ZIP link redirects to the current release.
- [ ] Current release notes include the install command.

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

Deployment checks are pending until the commit is pushed and Pages redeploys.

## Result

Status: `partial`

Reason: Local implementation checks pass; deployment verification is pending.
