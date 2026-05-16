# Closeout: Unsigned Install Bypass

## Shipped

- Hosted terminal installer for trusted ad-hoc signed releases.
- Download site install command and manual quarantine reset guidance.
- README install guidance for the macOS Trash prompt case.
- Future GitHub Release notes include the installer command.
- Current `v2026.20.1` release notes were updated with the same command.

## Changed Files

- `docs/install.sh`
- `docs/index.html`
- `docs/styles.css`
- `README.md`
- `.github/workflows/release.yml`
- `.agents/runs/unsigned-install-bypass/*`

## Verification

- `bash -n docs/install.sh`
- Local installer run against `.build/release-artifacts/Spill-2026.20.1-macos.zip`
  with temporary `SPILL_INSTALL_DIR` and `SPILL_OPEN_AFTER_INSTALL=0`.
- Workflow YAML parse for release and Pages workflows.
- `git diff --check`
- `python3 .agents/scripts/workflow.py verify`
- Pages deploy succeeded for `2524099`.
- Site redesign deploy succeeded for `8e3d426`.
- `curl -I https://thdev.app/Spill/`
- `curl -I https://thdev.app/Spill/install.sh`
- Deployed HTML contains the new hero copy and hosted installer command.

## Residual Risks

- Command-based quarantine removal is only appropriate for trusted unsigned
  releases.
- Developer ID signing and notarization are still required for warning-free public
  distribution.

## Follow-up Tasks

- Configure Apple Developer ID signing secrets.

## Docs Updated

- [x] PRD
- [x] ARD
- [ ] roadmap
- [x] README
