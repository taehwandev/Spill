# Closeout: Manual Update Check

## Shipped

- Added a manual update check backed by a static GitHub Release `update.json`
  manifest.
- Added Preferences status UI with current version, Check for Updates, Update,
  and Notes actions.
- Added Check for Updates to the app menu and status item context menu.
- Added release manifest generation and upload wiring.

## Changed Files

- `Sources/Spill/App/UpdateChecker.swift`
- `Sources/Spill/App/UpdateCheckStore.swift`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Preferences/GeneralPreferencesSection.swift`
- `Sources/Spill/Preferences/PreferencesView.swift`
- `Sources/Spill/Preferences/PreferencesWindowController.swift`
- `Sources/Spill/Preferences/UpdatePreferencesSection.swift`
- `Tests/SpillTests/UpdateCheckerTests.swift`
- `scripts/package-release.sh`
- `.github/workflows/release.yml`
- `README.md`
- `.agents/runs/manual-update-check`

## Verification

- `swift test`
- `bash -n scripts/package-release.sh`
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release.yml")'`
- `git diff --check -- . ':!docs/index.html' ':!.agents/runs/landing-page-showcase'`
- `./scripts/build-app.sh`
- `SPILL_VERSION=2026.20.99 SPILL_BUILD=999 ./scripts/package-release.sh`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py status-click-smoke`
- relaunched `.build/Spill.app`

## Residual Risks

- Existing public releases do not have `update.json`; update checks will show a
  retryable failure until the first release with the new manifest ships.
- Automatic update installation is intentionally deferred to a future Sparkle
  slice after signing/notarization decisions.
- Manual GUI inspection of the Preferences update section is still pending.

## Follow-up Tasks

- Add Sparkle appcast support after Developer ID signing and notarization are
  configured.
- Decide whether future automatic update checks default on, off, or require
  first-run consent.

## Docs Updated

- [x] PRD
- [x] ARD
- [ ] roadmap
- [x] README
