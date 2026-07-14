# Spill Token Metering Setup Request

Install or repair Spill token metering now with the one-step installer:

```bash
/bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)"
```

If shell, filesystem, sandbox, or user-level configuration permission is
required, explain why and ask for that permission before running the command.

## What The Installer Does

One run handles Codex, Claude Code, and Antigravity/AGY together. It:

- installs or refreshes the Codex and Claude exact-usage adapters;
- removes legacy managed AGY lifecycle hooks because AGY usage comes from
  Spill's local active importer;
- installs the read-only local usage status helper;
- configures narrow runtime labels and command permissions without adding broad
  `node`, `python3`, or shell-wide permissions;
- writes one canonical agent instruction to
  `~/.spill/runtime-instruction.md`;
- merges a small managed discovery bridge into Codex
  `~/.codex/AGENTS.override.md` when it already exists (otherwise
  `~/.codex/AGENTS.md`), Claude Code `~/.claude/CLAUDE.md`, and
  Antigravity/AGY `~/.antigravity/AGENTS.md`.

The bridge files remain small and preserve unrelated user instructions. Do not
copy the full Spill runtime prompt separately into Codex, Claude, or AGY files.
Do not ask the user to maintain three prompt copies. Already-running agent
sessions may need to restart before they load the new shared instruction.

## Privacy Boundary

Spill local importers may read known Codex or Claude JSONL session/transcript
files and Antigravity/AGY metadata records on this Mac only to extract exact
numeric token counts, timestamps, safe model ids, and opaque ids. They must not
store or upload prompts, responses, commands, file paths, transcript text,
logs, diffs, source content, environment values, or secrets.

Runtime collection remains intentionally different behind one normalized local
store:

- Codex imports exact token-count records from supported Codex session data.
- Claude Code uses its exact numeric transcript usage contract and native local
  importer paths.
- Antigravity/AGY uses Spill's local active importer. Do not install AGY
  `PostInvocation`, Stop, or lifecycle hooks.

The installed adapters normalize these sources into Spill's strict token-only
event schema. They never estimate missing token counts or infer labels and token
categories from private content.

## Completion And Verification

After the command finishes:

1. Report the installer's actual installed, repaired, skipped, or failed items.
2. Confirm that `~/.spill/runtime-instruction.md` exists and that the managed
   runtime bridges point to it without replacing unrelated instruction content.
3. Treat workflow-aware label integration as an optional follow-up, not an
   installation requirement. Fallback per-turn labels work without it.
4. Do not claim that setup output, a permission prompt, a label write, a hook
   configuration, a unit test, or a mock payload proves real usage was recorded.

Real usage evidence requires an exact safe event in Spill's local queue/store or
the matching runtime-specific exact-usage success diagnostic. In particular, an
AGY label permission prompt is label-only evidence, not token usage evidence.

When the user explicitly asks for Spill usage status, use the installed
read-only helper for the current runtime:

```bash
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool codex
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool claude
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool antigravity
```

Do not run the status helper in normal replies. It is a read-only report, not a
usage event, hook, importer, or proof that the current turn was recorded.
