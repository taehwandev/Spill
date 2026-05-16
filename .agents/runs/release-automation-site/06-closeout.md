# Closeout: Release Automation and Distribution Site

## Shipped

- GitHub Release workflow for tag and manual release publishing.
- Optional Developer ID signing and notarization path through GitHub Secrets.
- GitHub Pages deployment workflow for the static download site.
- Static `docs/` download site with the simplified Spill icon asset.
- Simplified generated app icon based on a teal spill mark.

## Changed Files

- `.github/workflows/release.yml`
- `.github/workflows/pages.yml`
- `docs/index.html`
- `docs/styles.css`
- `docs/assets/spill-icon.png`
- `scripts/generate-app-icon.swift`
- `scripts/build-app.sh`
- `scripts/package-release.sh`
- `README.md`
- `.agents/runs/release-automation-site/*`

## Verification

- `./scripts/build-app.sh`
- `./scripts/package-release.sh`
- `codesign --verify --deep --strict --verbose=2 .build/Spill.app`
- `hdiutil verify .build/release-artifacts/Spill-2026.20.1-macos.dmg`
- `unzip -t .build/release-artifacts/Spill-2026.20.1-macos.zip`
- `ruby -e 'require "yaml"; ...' .github/workflows/release.yml .github/workflows/pages.yml`
- `qlmanage -t -s 1200 -o /private/tmp docs/index.html`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `git diff --check`

## Residual Risks

- Developer ID signing and notarization require real Apple Developer credentials in GitHub Secrets and cannot be fully exercised without them.
- GitHub Pages will show working download links only after the first release uploads the stable `Spill-macos.*` assets.
- `actionlint` was not available locally, so GitHub workflow validation is limited to YAML parsing and manual review.

## Follow-up Tasks

- Add Homebrew Cask publishing after the first stable release.
- Add a custom domain if the project needs one.
- Consider an update feed after release cadence is established.

## Docs Updated

- [x] PRD
- [x] ARD
- [ ] roadmap
- [x] README
