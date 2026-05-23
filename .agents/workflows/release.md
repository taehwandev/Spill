# Spill Release Workflow

This workflow defines what repo agents should do when the maintainer asks for a
release, deploy, or distribution build.

## Trigger Contract

Treat these requests as release requests:

- `release`
- `release it`
- `make a release`
- `deploy`
- `ship it`
- Korean-language equivalents of release or deploy requests

Default behavior for an unqualified release request:

1. Release from the current repository state.
2. Commit all intended source, script, and documentation changes first, separated
   by logical purpose.
3. Use the next `ISO-year.ISO-week.release-count` version unless the maintainer
   provided a specific version.
4. Build and verify local release artifacts from the exact commit being tagged.
5. Create an annotated release tag.
6. Publish through the GitHub `Release` workflow when remote access is available.
7. Verify the GitHub Release, stable download assets, and update manifest.
8. Leave the release tag on the packaged commit even if documentation or
   workflow follow-up commits are added afterward.

Ask the maintainer only when a blocker remains after repo research, such as an
unclear version target, unrelated dirty files, an existing tag that points to a
different commit, missing signing credentials for a notarized release, or a
request that would overwrite an existing public release.

## Version Policy

Spill release versions use:

```text
ISO-year.ISO-week.release-count
```

Example:

```text
2026.20.2
```

Tags must use the same version with a leading `v`:

```text
v2026.20.2
```

If the maintainer does not provide a version:

1. Compute the current UTC ISO year and week.
2. Inspect local and remote tags for the same `year.week`.
3. Use the next release count after the highest existing tag for that week.
4. Use the release count as `SPILL_BUILD` unless the maintainer provided another
   build number.

Never reuse a tag for a different commit. If the tag already exists and points to
the intended release commit, continue with packaging or publishing. If it points
elsewhere, stop and ask.

## Release Tag Ownership

A release tag is owned by the exact commit used to build and publish release
artifacts. It is not a marker for the latest `main` commit.

Rules:

- Create the tag only after the release commit has passed local artifact
  verification.
- Keep the tag on the packaged commit after publication.
- Do not move the tag to later documentation, workflow, or telemetry-fix commits.
- If a post-release fix changes app behavior or release artifacts, publish a new
  version with a new tag.
- If a post-release fix changes only repository process, documentation, or Pages
  deployment behavior, commit it after the release tag and do not retag the
  previous release.
- Do not force-push a release tag unless the maintainer explicitly approves a
  public release correction.

Annotated tags have two identities:

- the tag object SHA;
- the peeled commit SHA, shown with `^{}`.

Use the peeled commit SHA when confirming which commit a release tag actually
points to:

```bash
git show-ref --tags -d v<version>
git tag --points-at <release-commit>
git tag --points-at HEAD
```

`git tag --points-at HEAD` returns the release tag only when `HEAD` is still the
release commit. If later commits were added after the release, this command can
return nothing even though the release tag is correct.

## Preflight

Read the standard agent entry points first:

```bash
sed -n '1,220p' .agents/README.md
sed -n '1,240p' .agents/workflows/implementation.md
sed -n '1,220p' .agents/workflows/ambiguity-gate.md
```

Inspect repository state:

```bash
git status --short
git log --oneline -5
git tag --list 'v*' --sort=-v:refname
```

When network access is available, refresh tags before deciding the next version:

```bash
git fetch --tags origin
```

Dirty tree handling:

- If files are clearly part of the current release work, commit them before
  tagging.
- Split commits by logical purpose, not by file extension.
- Do not include `.build/` artifacts in git.
- Do not revert unrelated user changes.
- Ask only if dirty changes are unrelated, risky, or impossible to classify.

## Verification Before Packaging

Run the minimum source checks:

```bash
swift test
python3 .agents/scripts/workflow.py verify
```

Run additional smoke checks when the release includes related changes:

```bash
python3 .agents/scripts/workflow.py runtime-smoke
python3 .agents/scripts/workflow.py panel-layout-smoke
python3 .agents/scripts/workflow.py status-click-smoke
```

Use judgment for scope. A pure documentation release does not need UI smoke
checks, but an app release should pass the checks relevant to changed behavior.

## Package From The Release Commit

Make sure the commit to be tagged is the one being packaged:

```bash
git status --short
git rev-parse --short HEAD
```

Build local artifacts:

```bash
SPILL_VERSION=<version> SPILL_BUILD=<build> ./scripts/package-release.sh
```

Local builds read `.env.local` automatically when present. For telemetry-enabled
artifacts, `.env.local` or the shell environment should provide:

- `SPILL_APTABASE_APP_KEY` for the macOS app bundle.
- `SPILL_WEB_APTABASE_APP_KEY` for the landing page when it should use a
  separate key.
- `SPILL_INSTALLER_APTABASE_APP_KEY` for `install.sh` when it should use a
  separate key.

The landing page and installer fall back to `SPILL_APTABASE_APP_KEY` when their
specific keys are absent.

For Developer ID signed and notarized releases, include the signing identity and
notary profile:

```bash
SPILL_VERSION=<version> \
SPILL_BUILD=<build> \
SPILL_SIGN_IDENTITY="Developer ID Application: Example Name (TEAMID)" \
SPILL_INSTALLER_SIGN_IDENTITY="Developer ID Installer: Example Name (TEAMID)" \
SPILL_NOTARY_KEYCHAIN_PROFILE="spill-notary" \
SPILL_SPARKLE_PUBLIC_ED_KEY="<public-ed-key>" \
SPILL_SPARKLE_PRIVATE_KEY_FILE="/path/to/sparkle_ed_private_key" \
./scripts/package-release.sh
```

The package script must produce:

- `.build/release-artifacts/Spill-<version>-macos.dmg`
- `.build/release-artifacts/Spill-<version>-macos.zip`
- `.build/release-artifacts/Spill-<version>-macos.pkg` when `SPILL_INSTALLER_SIGN_IDENTITY` is set
- `.build/release-artifacts/Spill-macos.dmg`
- `.build/release-artifacts/Spill-macos.zip`
- `.build/release-artifacts/Spill-macos.pkg` when `SPILL_INSTALLER_SIGN_IDENTITY` is set
- `.build/release-artifacts/update.json`
- `.build/release-artifacts/appcast.xml` when `SPILL_SPARKLE_PRIVATE_KEY_FILE` is set
- `.build/release-artifacts/checksums.txt`

## Verify Artifacts

Run:

```bash
hdiutil verify .build/release-artifacts/Spill-<version>-macos.dmg
unzip -t .build/release-artifacts/Spill-<version>-macos.zip
pkgutil --check-signature .build/release-artifacts/Spill-<version>-macos.pkg # when present
codesign --verify --deep --strict --verbose=2 .build/Spill.app
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" .build/Spill.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" .build/Spill.app/Contents/Info.plist
sed -n '1,120p' .build/release-artifacts/update.json
test -s .build/release-artifacts/appcast.xml # when Sparkle signing is configured
xcrun stapler validate .build/release-artifacts/Spill-<version>-macos.dmg # when notarized
```

Confirm:

- `CFBundleShortVersionString` equals `<version>`.
- `CFBundleVersion` equals `<build>`.
- `update.json.latestVersion` equals `<version>`.
- `update.json.downloadURL` points to
  `https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.dmg`.
- `update.json.packageURL` points to
  `https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.pkg`
  when a signed package is produced.
- Stable and versioned DMG/ZIP assets exist.
- Stable and versioned PKG assets exist when `SPILL_INSTALLER_SIGN_IDENTITY` is
  set.
- `appcast.xml` exists when Sparkle signing is configured and points at the
  versioned ZIP asset.
- Notarized DMG stapler validation passes when notarization is configured.

## Tag

Create an annotated tag after successful local verification:

```bash
git tag -a v<version> -m "Release <version>"
git tag --points-at HEAD
```

If a matching tag already exists at `HEAD`, keep it. Do not recreate it unless
the maintainer explicitly asks for a retag.

If a matching tag already exists on the intended release commit but `HEAD` has
advanced, keep the tag where it is. Report both the release commit and current
`HEAD` in the closeout.

## Publish

Canonical publication path:

```bash
git push origin main
git push origin v<version>
```

Verify the remote tag target after pushing:

```bash
git ls-remote --tags origin "v<version>*"
```

For annotated tags, confirm the `refs/tags/v<version>^{}` line matches the
release commit SHA.

The tag push starts `.github/workflows/release.yml`. Monitor it:

```bash
gh run list --workflow Release --limit 3
gh run watch <run-id>
gh release view v<version>
```

The workflow should create or update the GitHub Release and upload:

- `Spill-<version>-macos.dmg`
- `Spill-<version>-macos.zip`
- `Spill-<version>-macos.pkg` when Developer ID Installer signing is configured
- `Spill-macos.dmg`
- `Spill-macos.zip`
- `Spill-macos.pkg` when Developer ID Installer signing is configured
- `update.json`
- `appcast.xml` when Sparkle signing is configured
- `checksums.txt`

Manual asset upload is a fallback only when GitHub Actions is unavailable. Prefer
the workflow so the public release is reproducible from the tag.

For telemetry-enabled public releases, GitHub Secrets should include:

- `SPILL_APTABASE_APP_KEY`
- `SPILL_WEB_APTABASE_APP_KEY` when the landing page should use a separate key
- `SPILL_INSTALLER_APTABASE_APP_KEY` when the installer should use a separate key
- `SPARKLE_PUBLIC_ED_KEY` and `SPARKLE_PRIVATE_ED_KEY` when official in-app
  Sparkle updates should be enabled

The release workflow embeds the app key in the macOS app bundle. The Pages
workflow runs `scripts/prepare-docs.sh` and deploys `.build/docs` so the landing
page and installer script receive telemetry keys. The Pages workflow falls back
to `SPILL_APTABASE_APP_KEY` when page-specific keys are absent.

## Post-Release Checks

After GitHub publication, verify stable public URLs:

```bash
curl -I -L https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.dmg
curl -I -L https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.zip
curl -I -L https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.pkg # when package signing is configured
curl -fsSL https://github.com/taehwandev/Spill/releases/latest/download/update.json
curl -fsSL https://github.com/taehwandev/Spill/releases/latest/download/appcast.xml # when Sparkle signing is configured
curl -I -L https://spill.thdev.app/
```

Open the release page and confirm:

- the latest release tag is correct;
- stable assets resolve;
- `update.json` is attached;
- `update.json.packageURL` is present when the release includes a signed package;
- `appcast.xml` is attached when Sparkle signing is configured;
- the download site still points at stable assets;
- a Sparkle-enabled older build can check, download, and replace the app from
  inside Spill;
- a non-Sparkle older build can still discover the release from `update.json`
  and opens the signed package when `packageURL` is present.

## Do Not

- Do not tag before committing intended release changes.
- Do not package a dirty working tree unless the dirt is generated output under
  ignored paths.
- Do not publish a release with an ad-hoc signature if the maintainer requested a
  notarized public release.
- Do not overwrite an existing public release without explicit maintainer
  approval.
- Do not move a release tag after publication without explicit maintainer
  approval.
- Do not claim Sparkle is enabled unless the app bundle contains `SUFeedURL` and
  `SUPublicEDKey` and the release has an attached `appcast.xml`.

## Closeout

Report:

- release version and build number;
- release commit hash;
- tag name;
- whether the tag was pushed;
- whether GitHub Release publication passed;
- artifact paths or GitHub URLs;
- verification commands run;
- any signing/notarization limitations.
