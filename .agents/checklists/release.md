# Release Checklist

Use AgentPlaybook `workflows/release-readiness.md` as the shared release
procedure. This checklist is the Spill-specific quick gate before closeout.

## Scope

- [ ] The release request, target version, and publication scope are clear.
- [ ] The working tree is clean or all intended changes are committed.
- [ ] Unrelated dirty files are excluded or escalated to the maintainer.
- [ ] The target commit is the commit that will be tagged and packaged.

## Version And Tag

- [ ] Version uses `ISO-year.ISO-week.release-count`, for example `2026.20.2`.
- [ ] Build number equals the full version string (`SPILL_BUILD` defaults to `SPILL_VERSION`).
- [ ] Existing local and remote tags were checked.
- [ ] Annotated tag `v<version>` points at the release commit.
- [ ] The release tag is treated as the packaged commit, not as the latest
      `main` commit.
- [ ] If `HEAD` advanced after release tagging, the tag was not moved.
- [ ] For annotated tags, the remote peeled `v<version>^{}` target was verified.
- [ ] No existing published tag or release is being overwritten without approval.

## Source Verification

- [ ] `swift test`
- [ ] `python3 .agents/scripts/workflow.py verify`
- [ ] `python3 .agents/scripts/workflow.py runtime-smoke` when app startup,
      packaging, permissions, or lifecycle changed.
- [ ] `python3 .agents/scripts/workflow.py panel-layout-smoke` when panel UI or
      sizing changed.
- [ ] `python3 .agents/scripts/workflow.py status-click-smoke` when menu bar
      trigger behavior changed.

## Packaging

- [ ] `SPILL_SKIP_ENV_LOCAL=1 SPILL_VERSION=<version> SPILL_BUILD_PRIVATE_USAGE_ENVIRONMENT=production ./scripts/package-release.sh` (`SPILL_BUILD` defaults to `<version>`)
- [ ] Telemetry key source is explicit: shell environment, `.env.local`, GitHub
      Secrets, or intentionally disabled.
- [ ] Versioned DMG exists.
- [ ] Stable `Spill-macos.dmg` exists.
- [ ] `update.json` exists.
- [ ] `appcast.xml` exists after the official workflow prepares Sparkle assets.
- [ ] `checksums.txt` exists.

## Artifact Verification

- [ ] `hdiutil verify .build/release-artifacts/Spill-<version>-macos.dmg`
- [ ] `hdiutil verify .build/release-artifacts/Spill-macos.dmg`
- [ ] `codesign --verify --deep --strict --verbose=2 .build/Spill.app`
- [ ] `xcrun stapler validate .build/release-artifacts/Spill-<version>-macos.dmg`
      when notarized.
- [ ] `CFBundleShortVersionString` equals `<version>`.
- [ ] `CFBundleVersion` equals `<version>` (build number = full version string).
- [ ] `update.json.latestVersion` equals `<version>`.
- [ ] `update.json.downloadURL` points at the stable latest DMG URL.
- [ ] `appcast.xml` points at the stable latest DMG URL.

## Signing And Notarization

- [ ] Signing mode is explicit: ad-hoc, Developer ID signed, or notarized.
- [ ] Developer ID certificate is available when required.
- [ ] Hardened runtime is enabled.
- [ ] Notarization profile is available when required.
- [ ] Notarization accepted and stapled when required.
- [ ] Gatekeeper behavior is documented if the release is ad-hoc signed.

## Publication

- [ ] `git push origin main`
- [ ] `git push origin v<version>`
- [ ] GitHub Actions repository variables are set for production private usage
      upload: `SPILL_BUILD_PRIVATE_USAGE_FEATURE_ENABLED=1`,
      `SPILL_BUILD_PRIVATE_USAGE_WEB_URL=https://spill.thdev.app/`. The app
      derives the relay URL from the web origin.
- [ ] GitHub Secrets include `SPILL_APTABASE_APP_KEY` when public metrics are
      expected. `SPILL_WEB_APTABASE_APP_KEY` and
      `SPILL_INSTALLER_APTABASE_APP_KEY` are optional separate-key overrides.
- [ ] GitHub Secrets include `SPARKLE_PUBLIC_ED_KEY` and
      `SPARKLE_PRIVATE_ED_KEY`.
- [ ] GitHub Actions workflow token can publish releases: repository workflow
      permissions are `write` or the release workflow uses a dedicated
      write-capable release token.
- [ ] GitHub `Release` workflow completed successfully.
- [ ] GitHub Release for `v<version>` exists.
- [ ] Stable `Spill-macos.dmg` is attached.
- [ ] `update.json` is attached.
- [ ] `appcast.xml` is attached.
- [ ] `checksums.txt` is attached.

## Public URL Checks

- [ ] Latest stable DMG URL resolves.
- [ ] Latest `update.json` URL resolves.
- [ ] Latest `appcast.xml` URL resolves.
- [ ] `https://spill.thdev.app/` resolves when the hosted web portal is part
      of the release scope.
- [ ] Sparkle-enabled Check for Updates can download and replace the app from an
      older build.
- [ ] Manual fallback Check for Updates can discover the new release from an
      older non-Sparkle build.

## Closeout

- [ ] Report version and build.
- [ ] Report release commit hash.
- [ ] Report current `HEAD` if it differs from the release commit.
- [ ] Report tag name.
- [ ] Report whether the tag was pushed.
- [ ] Report GitHub Release status.
- [ ] Report local artifact paths or public URLs.
- [ ] Report verification commands.
- [ ] Report signing or notarization limitations.
