# Release Checklist

Use `.agents/workflows/release.md` as the full release procedure. This checklist
is the quick gate before closeout.

## Scope

- [ ] The release request, target version, and publication scope are clear.
- [ ] The working tree is clean or all intended changes are committed.
- [ ] Unrelated dirty files are excluded or escalated to the maintainer.
- [ ] The target commit is the commit that will be tagged and packaged.

## Version And Tag

- [ ] Version uses `ISO-year.ISO-week.release-count`, for example `2026.20.2`.
- [ ] Build number is set intentionally.
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

- [ ] `SPILL_VERSION=<version> SPILL_BUILD=<build> ./scripts/package-release.sh`
- [ ] Telemetry key source is explicit: shell environment, `.env.local`, GitHub
      Secrets, or intentionally disabled.
- [ ] Versioned DMG exists.
- [ ] Versioned ZIP exists.
- [ ] Stable `Spill-macos.dmg` exists.
- [ ] Stable `Spill-macos.zip` exists.
- [ ] `update.json` exists.
- [ ] `appcast.xml` exists.
- [ ] `checksums.txt` exists.

## Artifact Verification

- [ ] `hdiutil verify .build/release-artifacts/Spill-<version>-macos.dmg`
- [ ] `unzip -t .build/release-artifacts/Spill-<version>-macos.zip`
- [ ] `codesign --verify --deep --strict --verbose=2 .build/Spill.app`
- [ ] `xcrun stapler validate .build/release-artifacts/Spill-<version>-macos.dmg`
      when notarized.
- [ ] `CFBundleShortVersionString` equals `<version>`.
- [ ] `CFBundleVersion` equals `<build>`.
- [ ] `update.json.latestVersion` equals `<version>`.
- [ ] `update.json.downloadURL` points at the stable latest DMG URL.
- [ ] `appcast.xml` points at the versioned ZIP URL.

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
- [ ] GitHub Secrets include `SPILL_APTABASE_APP_KEY` when public metrics are
      expected. `SPILL_WEB_APTABASE_APP_KEY` and
      `SPILL_INSTALLER_APTABASE_APP_KEY` are optional separate-key overrides.
- [ ] GitHub Secrets include `SPARKLE_PUBLIC_ED_KEY` and
      `SPARKLE_PRIVATE_ED_KEY`.
- [ ] GitHub `Release` workflow completed successfully.
- [ ] GitHub Release for `v<version>` exists.
- [ ] Stable and versioned assets are attached.
- [ ] `update.json` is attached.
- [ ] `appcast.xml` is attached.
- [ ] `checksums.txt` is attached.

## Public URL Checks

- [ ] Latest stable DMG URL resolves.
- [ ] Latest stable ZIP URL resolves.
- [ ] Latest `update.json` URL resolves.
- [ ] Latest `appcast.xml` URL resolves.
- [ ] `https://spill.thdev.app/` resolves.
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
