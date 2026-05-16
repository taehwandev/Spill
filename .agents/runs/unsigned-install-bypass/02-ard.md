# Detailed ARD: Unsigned Install Bypass

## Architecture Summary

Add a static shell installer hosted by GitHub Pages. It uses the stable GitHub
Release ZIP asset, installs the app into a configurable directory, removes the
quarantine extended attribute, and optionally opens the app.

## Decisions

### D1: Hosted Installer Script

Decision:

Serve `install.sh` from `docs/` so users can run one command from the download
site.

Rationale:

The site is already deployed by GitHub Pages and can host static files without a
new service.

Alternatives considered:

- README-only `xattr` command: useful but less convenient for new installs.
- Rebuild current release only: does not solve unsigned Gatekeeper behavior.
- Notarization now: blocked until Apple Developer credentials are configured.

### D2: ZIP-Based Install

Decision:

Download `Spill-macos.zip` instead of the DMG for the terminal installer.

Rationale:

ZIP extraction is straightforward with `ditto` and does not require mounting or
detaching disk images.

Alternatives considered:

- DMG install script: more moving parts and mount cleanup.

## Modules Affected

- `docs/install.sh`
- `docs/index.html`
- `docs/styles.css`
- `README.md`
- `.github/workflows/release.yml`

## New Types / APIs

No Swift APIs.

Shell environment overrides:

```bash
SPILL_DOWNLOAD_URL
SPILL_INSTALL_DIR
SPILL_OPEN_AFTER_INSTALL
```

## Data Flow

```text
latest ZIP release -> temp directory -> ditto extract -> install directory -> xattr cleanup -> open
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: unchanged.
- Network: installer downloads the release ZIP.
- File system: installer writes to `/Applications` by default and may request
  `sudo`.

## Failure Modes

- Download fails: `curl` exits non-zero.
- Archive missing app: script prints an explicit error and exits with code 2.
- `/Applications` requires admin: script uses `sudo`.
- User distrusts shell install: direct DMG/ZIP links remain available.

## Performance Notes

The installer runs outside the app and has no runtime performance impact.

## Test Strategy

### Automated

- `bash -n docs/install.sh`
- Run installer against a local release ZIP with `SPILL_INSTALL_DIR` pointing at a
  temporary directory and `SPILL_OPEN_AFTER_INSTALL=0`.
- YAML parse for workflow changes.
- `git diff --check`.

### Manual

- Confirm the site returns HTTP 200 after Pages deploy.
- Confirm latest release download links still redirect.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Installer | builder | `docs/install.sh` | yes |
| Documentation/site | builder | `docs/index.html`, `docs/styles.css`, `README.md` | yes |
| Release notes | builder | `.github/workflows/release.yml` | yes |
| Verification | verifier | command checks and Pages deploy | no |

## Risks

- Command-based install is a trust-sensitive path; keep it short and visible.
- Quarantine removal is only appropriate for trusted builds.
- Notarization remains required for warning-free public distribution.
