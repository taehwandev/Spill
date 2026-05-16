# Verification: Release Automation and Distribution Site

## Build Checks

- [x] `./scripts/build-app.sh`
- [x] `./scripts/package-release.sh`
- [x] `codesign --verify --deep --strict --verbose=2 .build/Spill.app`
- [x] `hdiutil verify .build/release-artifacts/Spill-2026.20.1-macos.dmg`
- [x] `unzip -t .build/release-artifacts/Spill-2026.20.1-macos.zip`
- [x] `python3 .agents/scripts/workflow.py verify`
- [x] `python3 .agents/scripts/workflow.py runtime-smoke`
- [x] `git diff --check`

## Manual Checks

- [x] Release workflow uses `scripts/package-release.sh`.
- [x] Release workflow derives version from tag or current UTC ISO year/week plus manual release count.
- [x] Release workflow uploads versioned and stable asset names.
- [x] Pages workflow deploys `docs/`.
- [x] Static site includes DMG, ZIP, source, and releases links.
- [x] Quick Look preview rendered the static site.

## Feature Checks

- [x] Unsigned release path remains available for test artifacts.
- [x] Developer ID signing and notarization path is documented and secret-gated.
- [x] Download links use stable `latest/download` asset names.
- [x] App icon and site icon use the simplified Spill mark.

## Regression Checks

- [x] No app source behavior changed.
- [x] No private API usage introduced.
- [x] Existing package script still works locally.

## Notes

`actionlint` was not installed locally, so workflow YAML was parsed with Ruby's YAML parser. `xmllint` and the installed `tidy` build only understand older HTML tag sets and report HTML5 structural tags as unknown despite `xmllint` returning success; visual site preview was verified with Quick Look.

## Result

Status: `pass`

Reason: Release automation, site assets, package artifacts, and runtime smoke verification passed locally.
