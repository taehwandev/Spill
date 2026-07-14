# Spill Token Metering Public Install Files

`docs/token-metering/` is the open-source source of truth for the public token
metering installer and agent prompt contract:

- `install.sh`
- `setup-prompt.md`
- `runtime-instruction.md`

`runtime-instruction.md` is the canonical instruction source installed at
`~/.spill/runtime-instruction.md`. The setup helper keeps the runtime-specific
Codex, Claude Code, and Antigravity/AGY instruction files limited to a small
managed import or pointer, preserving unrelated user content instead of copying
the full prompt three times.

The production web host is `https://spill.thdev.app/`. The web deployment must
publish the same installer and prompt files at `/token-metering/`.

## Cross-Repo Sync

When editing any install or prompt file in this directory, also update the
private web repository mirrors:

- `../Spill-web/docs/token-metering/`
- `../Spill-web/web/public/token-metering/`

From `../Spill-web`, run:

```bash
./scripts/sync-prompts.sh
```

Then review both repositories for the same production install URL:

```text
https://spill.thdev.app/token-metering/install.sh
```

Do not change the app installer contract in this repository without checking
the web mirror. Conversely, when changing the public installer or prompt files
in `../Spill-web`, update this directory first or bring the same change back
here before release.
