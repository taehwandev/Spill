# Closeout: Manual Update Check

## Shipped

- Added a manual update check backed by a static GitHub Release `update.json`
  manifest.
- Added a GitHub latest release fallback for public releases that do not yet
  include `update.json`.
- Removed the forced test update state from startup.
- Added a compact panel update row and a Preferences Terminal install command
  copy action for available updates.
- Added Preferences status UI with current version, Check for Updates, Copy
  Install Command, Download DMG, and Notes actions.
- Added Check for Updates to the app menu and status item context menu.
- Added release manifest generation and upload wiring.

## Changed Files

- `Sources/Spill/App/UpdateChecker.swift`
- `Sources/Spill/App/UpdateCheckStore.swift`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelContentSizer.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Preferences/GeneralPreferencesSection.swift`
- `Sources/Spill/Preferences/PreferencesView.swift`
- `Sources/Spill/Preferences/PreferencesWindowController.swift`
- `Sources/Spill/Preferences/UpdatePreferencesSection.swift`
- `Tests/SpillTests/UpdateCheckerTests.swift`
- `Tests/SpillTests/UpdateCheckStoreTests.swift`
- `Tests/SpillTests/SpillPanelLayoutTests.swift`
- `scripts/package-release.sh`
- `.github/workflows/release.yml`
- `README.md`
- `.agents/runs/manual-update-check`

## Verification

- `swift test`
- `bash -n scripts/package-release.sh`
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release.yml")'`
- `git diff --check -- . ':!docs/index.html'`
- `./scripts/build-app.sh`
- `SPILL_VERSION=2026.20.99 SPILL_BUILD=999 ./scripts/package-release.sh`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py status-click-smoke`
- relaunched `.build/Spill.app`

## Residual Risks

- Existing public releases do not have `update.json`; update checks now fall
  back to latest release metadata, but exact build/minimum OS metadata remains
  limited until the first release with the manifest ships.
- Automatic update installation is intentionally deferred to a future Sparkle
  slice after signing/notarization decisions.
- The Terminal command is copied, not executed, so users must paste and run it
  themselves.
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
