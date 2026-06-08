# Spill

Spill is an open-source compact control tray for macOS. It keeps one visible menu bar trigger and opens a small native panel for useful system state, AI tool state, pinned actions, and focused window controls.

## Current status

This repository currently contains an MVP shell:

- menu bar status item
- generated app icon applied to bundled `.app` builds
- GitHub Release and GitHub Pages distribution automation
- click-to-toggle floating Spill Bar anchored to the status item
- optional CPU, memory, and active Caffeine menu bar glance chips, with an opt-in Caffeine countdown
- CPU, memory, and storage panel rows with compact sparklines
- right-click menu with preferences and app quit actions
- visible panel Close control that hides the panel without quitting Spill
- SwiftUI preferences window
- Accessibility permission status and diagnostics
- Launch at Login wiring for packaged `.app` builds
- Accessibility-based menu bar extra scanner using `AXExtrasMenuBar`
- best-effort `AXPress` action for detected items
- focused-window quick actions for halves, corners, center, maximize, display left/right, and restore
- automatic rescanning when apps, Spaces, or displays change
- optional `Control + Option + Space` global shortcut, with window action shortcuts grouped under `Control + Option` and display moves under `Control + Option + Command`
- notch-candidate menu bar actions with advanced detection diagnostics
- selectable detected items with persisted Spill Bar pinning and removal
- app-icon based labels for detected menu bar items
- fixed CPU, memory, and storage panel status rows
- click-to-open status detail popovers with CPU, memory, and Caffeine menu bar visibility toggles
- local AI status strip for Codex, Ollama, and OpenAI configuration
- pinned menu bar actions with pin/unpin controls, execution feedback, and app activation fallback
- Caffeine with configurable default duration and an opt-in never-ending duration

The current Spill Bar can detect some visible menu bar extras when Accessibility permission is granted. This is best-effort behavior. Spill does not promise to recover every item hidden behind the notch or forcibly rearrange other apps' menu bar items.

## Hosted web portal

The hosted account web portal for `spill.thdev.app` lives in the private
`taehwandev/Spill-web` repository. This public repository keeps the open-source
macOS app, local token-metering contracts, installer documents, and privacy
requirements. Browser-delivered web code is not a security boundary; hosted
account reads, device actions, and admin actions must still be enforced by the
server-side Supabase/RLS relay boundary.

## Important macOS constraint

macOS does not provide a public API that reliably enumerates, hides, resizes, reorders, clones, or reparents every third-party menu bar extra. `NSStatusBar` works for Spill's own item. Other apps' items live in their own processes, and deep control usually requires Accessibility observation, user-approved automation, or private implementation details.

For an open-source app, the practical direction is:

1. Use public AppKit/SwiftUI for the Spill UI.
2. Ask for Accessibility permission only when needed.
3. Detect visible menu bar items conservatively.
4. Build first-party compact controls instead of relying on fragile spacer behavior.
5. Avoid private APIs until there is a clearly documented reason and risk.

The current scanner is intentionally conservative. It prefers `AXExtrasMenuBar` and only falls back to `AXMenuBar` for Apple system menu-bar hosts, because scanning every app's normal menu bar would incorrectly collect File/Edit/View menu items.

## Requirements

- macOS 14 or newer
- Xcode 26 or newer, or a compatible Swift toolchain

## Run

```bash
swift run Spill
```

Spill runs as a menu bar utility and uses an accessory activation policy, so it does not show a Dock icon. Use the menu bar trigger to open the panel. The panel Close control hides the panel without quitting; to terminate the app, use the menu bar trigger's right-click menu and choose `Quit Spill`.

## Build

```bash
swift build
```

To create a local `.app` bundle:

```bash
cp .env.example .env.local
# Edit .env.local if the private usage web or relay URL differs.
./scripts/build-app.sh
open .build/Spill.app
```

Use `SPILL_SKIP_ENV_LOCAL=1 ./scripts/build-app.sh` when you need a clean local
development build that ignores an existing `.env.local`.

The bundled app declares `LSUIElement` and also runs without a Dock icon. If the app appears to do nothing after launch, check the menu bar for the Spill trigger.
Production app bundles read the private usage web and relay URLs from build-time
environment values written into `Info.plist`; the app source does not hardcode
the deployed web portal URL.

Agent-facing details for local app builds, app restarts, release packaging, and
token-metering adapter resource propagation live in
[.agents/build-and-run.md](.agents/build-and-run.md).

During development, avoid rebuilding the `.app` while testing Accessibility permission. macOS can treat a newly rebuilt local app as a new permission target.

### Screen Time and App Limits

macOS Screen Time can block any app with App Limits or Downtime. When a limit is
active, macOS may show a `Time Limit` shield above the blocked app and intercept
normal mouse or keyboard input. Spill cannot and should not bypass that system
control.

For reliable use:

- Install and launch Spill as its own app from `/Applications` or Finder.
- Do not use a blocked terminal, launcher, or browser as the manual test surface.
- If Spill itself is limited, open System Settings > Screen Time and add Spill to
  Always Allowed, or turn off the relevant App Limit.
- If another app is showing the Time Limit shield, clear that shield before
  judging Spill menu bar clicks.

The repository includes `./scripts/verify-status-click-smoke.sh` to verify the
Spill status item click route without relying on manual input from a limited app.

## Distribution

Create local release artifacts:

```bash
./scripts/package-release.sh
```

Local builds automatically read `.env.local` when present. Copy `.env.example`
to `.env.local` and fill telemetry keys before building if analytics should be
enabled in local app, landing page, or installer artifacts. Keep
`SPILL_BUILD_PRIVATE_USAGE_ENVIRONMENT=production`,
`SPILL_BUILD_PRIVATE_USAGE_WEB_URL` and `SPILL_BUILD_PRIVATE_USAGE_RELAY_URL`
set explicitly for production artifacts.

This writes:

- `.build/release-artifacts/Spill-2026.20.1-macos.zip`
- `.build/release-artifacts/Spill-2026.20.1-macos.dmg`

Without Apple credentials these artifacts are ad-hoc signed and useful for local
testing or trusted manual sharing. Official public distribution should use
Developer ID signing and notarization so Gatekeeper can validate the app.

### Installing ad-hoc test releases

Ad-hoc builds are for local validation only. macOS can show an unsigned
downloaded app as damaged and offer to move it to Trash. For trusted test
installs, use the hosted installer command:

```bash
/bin/bash -c "$(curl -fsSL https://spill.thdev.app/install.sh)"
```

The installer downloads the latest ZIP release, copies `Spill.app` to
`/Applications`, removes the `com.apple.quarantine` download attribute, and opens
the app. If Spill is already in Applications, the manual equivalent is:

```bash
sudo xattr -dr com.apple.quarantine /Applications/Spill.app
open /Applications/Spill.app
```

Developer ID release example:

```bash
SPILL_VERSION=2026.21.2 \
SPILL_BUILD_PRIVATE_USAGE_ENVIRONMENT=production \
SPILL_BUILD_PRIVATE_USAGE_RELAY_URL=<private-usage-relay-url> \
SPILL_BUILD_PRIVATE_USAGE_WEB_URL=<web-connect-device-url> \
SPILL_SIGN_IDENTITY="Developer ID Application: Example Name (TEAMID)" \
SPILL_INSTALLER_SIGN_IDENTITY="Developer ID Installer: Example Name (TEAMID)" \
./scripts/package-release.sh
```

For local notarization tests, use App Store Connect Team API key auth. The full
local sequence is build, notarize the app bundle, package from that notarized app
without rebuilding, then notarize the packaged DMG/PKG artifacts. Keep the `.p8`
file outside the repository and pass its ignored path only to the notarization
script:

```bash
SPILL_VERSION=2026.21.2 \
SPILL_BUILD_PRIVATE_USAGE_ENVIRONMENT=production \
SPILL_BUILD_PRIVATE_USAGE_RELAY_URL=<private-usage-relay-url> \
SPILL_BUILD_PRIVATE_USAGE_WEB_URL=<web-connect-device-url> \
SPILL_SIGN_IDENTITY="Developer ID Application: Example Name (TEAMID)" \
SPILL_INSTALLER_SIGN_IDENTITY="Developer ID Installer: Example Name (TEAMID)" \
./scripts/build-app.sh

APPLE_NOTARYTOOL_API_KEY_PATH=/path/to/AuthKey_EXAMPLE.p8 \
APPLE_NOTARYTOOL_API_KEY_ID=EXAMPLE123 \
APPLE_NOTARYTOOL_API_ISSUER=00000000-0000-0000-0000-000000000000 \
./scripts/notarize-release-artifacts.sh --app .build/Spill.app

SPILL_VERSION=2026.21.2 \
SPILL_SKIP_BUILD=1 \
SPILL_SIGN_IDENTITY="Developer ID Application: Example Name (TEAMID)" \
SPILL_INSTALLER_SIGN_IDENTITY="Developer ID Installer: Example Name (TEAMID)" \
./scripts/package-release.sh

APPLE_NOTARYTOOL_API_KEY_PATH=/path/to/AuthKey_EXAMPLE.p8 \
APPLE_NOTARYTOOL_API_KEY_ID=EXAMPLE123 \
APPLE_NOTARYTOOL_API_ISSUER=00000000-0000-0000-0000-000000000000 \
./scripts/notarize-release-artifacts.sh --artifacts .build/release-artifacts
```

Release versions use `ISO-year.ISO-week.release-count`, such as `2026.20.1`.
The default local version is the current ISO year/week with release count `1`.
`SPILL_BUILD` defaults to the final version component, so
`SPILL_VERSION=2026.21.2` uses build `2` unless overridden. Use `SPILL_VERSION`,
`SPILL_BUILD`, and `SPILL_BUNDLE_ID` to override release metadata.

### GitHub Releases

Push a version tag to create or update a GitHub Release:

```bash
git tag -a v2026.20.1 -m "Release 2026.20.1"
git push origin v2026.20.1
```

The `Release` workflow builds the macOS app, runs the package script, verifies the
bundle and archives, and uploads these assets:

- `Spill-2026.20.1-macos.dmg`
- `Spill-2026.20.1-macos.zip`
- `Spill-2026.20.1-macos.pkg`, when Developer ID Installer signing is configured
- `Spill-macos.dmg`
- `Spill-macos.zip`
- `Spill-macos.pkg`, when Developer ID Installer signing is configured
- `update.json`
- `appcast.xml`
- `checksums.txt`

The stable `Spill-macos.*` asset names are used by the download site. The workflow
can also be started manually from GitHub Actions with a per-week release count.
Manual runs compute the version from the current UTC ISO year/week plus that
count. Official releases use Sparkle for in-app update checks, downloads, and
app replacement. The workflow requires `SPARKLE_PUBLIC_ED_KEY` and
`SPARKLE_PRIVATE_ED_KEY` so it can embed `SUPublicEDKey` and upload
`appcast.xml`. The workflow also uploads `update.json`, a small static manifest
used for dashboard update discovery and as the fallback manual Check for Updates
path when Sparkle is not configured in the app bundle.

Local unsigned test packages can be built without secrets and are ad-hoc signed.
For official GitHub releases, configure the Sparkle secrets below. For Developer
ID signing and notarization, configure the Apple signing secrets as well:

- `MACOS_DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded `.p12` certificate.
- `MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD`: `.p12` import password.
- `MACOS_CODESIGN_IDENTITY`: full Developer ID identity, for example `Developer ID Application: Example Name (TEAMID)`.
- `MACOS_DEVELOPER_ID_INSTALLER_CERTIFICATE_BASE64`: optional base64-encoded Developer ID Installer `.p12` certificate for signed `.pkg` updates.
- `MACOS_DEVELOPER_ID_INSTALLER_CERTIFICATE_PASSWORD`: optional `.p12` import password for the installer certificate.
- `MACOS_INSTALLER_SIGN_IDENTITY`: optional full Developer ID Installer identity, for example `Developer ID Installer: Example Name (TEAMID)`.
- `MACOS_SIGNING_KEYCHAIN_PASSWORD`: optional temporary CI keychain password.
- `APPLE_NOTARYTOOL_API_KEY`: App Store Connect Team API private key `.p8` file contents.
- `APPLE_NOTARYTOOL_API_KEY_ID`: App Store Connect API Key ID.
- `APPLE_NOTARYTOOL_API_ISSUER`: App Store Connect API Issuer ID.
- `SPARKLE_PUBLIC_ED_KEY`: Sparkle public EdDSA key embedded as `SUPublicEDKey`.
- `SPARKLE_PRIVATE_ED_KEY`: Sparkle private EdDSA key used by `generate_appcast`.

If the Developer ID certificate secrets are present, the workflow signs with that
identity. Notarization uses the App Store Connect API key values in a separate
script step; the `.p8` content is written only to a temporary `mktemp` directory
with private permissions and is removed after the step. If the Developer ID
Installer secrets are also present, the workflow additionally builds, signs,
notarizes, and uploads stable `.pkg` installer assets. When
Sparkle is configured in the app bundle, Check for Updates uses Sparkle's in-app
updater first. Older non-Sparkle builds still fall back to the public
`update.json` manifest and open the installer package or DMG externally.

Optional telemetry secrets:

- `SPILL_APTABASE_APP_KEY`: shared analytics key. It is embedded in release app
  bundles and is also used by the landing page and installer when more specific
  keys are absent.
- `SPILL_WEB_APTABASE_APP_KEY`: optional landing page analytics key injected
  during Pages deployment.
- `SPILL_INSTALLER_APTABASE_APP_KEY`: optional installer script analytics key
  injected during Pages deployment.

### Download Site

The static distribution site source lives in `docs/`. The `Deploy Site` workflow
runs `scripts/prepare-docs.sh`, injects optional telemetry keys from GitHub
Secrets, and deploys `.build/docs` to GitHub Pages. The site links to the latest
stable release assets:

- `https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.dmg`
- `https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.zip`
- `https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.pkg`, when Developer ID Installer signing is configured

The deploy workflow attempts to enable GitHub Pages with the GitHub Actions
source and publishes the site for `spill.thdev.app`. If repository policy blocks
automatic enablement, enable GitHub Pages manually with the GitHub Actions source
and set the custom domain to `spill.thdev.app`.

## Verify

Run deterministic checks:

```bash
python3 .agents/scripts/workflow.py verify
```

Run the bundled app smoke test:

```bash
python3 .agents/scripts/workflow.py runtime-smoke
```

The runtime smoke test builds `.build/Spill.app`, launches the app in `SPILL_SMOKE_TEST` mode, verifies startup readiness, and confirms clean shutdown without opening Preferences or requesting Accessibility permission.

Run the compact panel smoke test:

```bash
python3 .agents/scripts/workflow.py panel-layout-smoke
```

The panel smoke test opens the bundled panel in smoke mode and verifies frame,
content, and key accessibility labels without relying on manual Accessibility
permission setup.

Run the status item click smoke test:

```bash
python3 .agents/scripts/workflow.py status-click-smoke
```

This verifies the menu bar status item click route without relying on manual
input from an app that may be blocked by Screen Time.

## Roadmap

| Phase | Goal | Scope |
| --- | --- | --- |
| 1 | Product reset | Single visible trigger, no spacer dependency, compact tray direction |
| 2 | Panel shell | System, AI, pinned action, and window action sections |
| 3 | Provider models | Plain model types and provider boundaries |
| 4 | System and AI status | Lightweight local status providers with conservative refresh |
| 5 | Actions | Pinned actions and focused-window quick actions |
| 6 | Preferences | Strip toggles, permission diagnostics, launch at login, optional hotkey |
| 7 | Distribution | Signed app bundle, notarization path, releases, contribution guide |

## License

MIT. See [LICENSE](LICENSE).
