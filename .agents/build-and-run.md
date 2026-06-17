---
title: Spill App Build And Run Guide
audience: Claude Code, Codex, Antigravity/AGY, and local contributors
purpose: Explain exactly how to build, bundle, restart, package, and verify the Spill macOS app without confusing compiled binaries, app bundles, bundled resources, and installed token-metering hooks.
status: stable
source_of_truth: Package.swift, scripts/build-app.sh, scripts/package-release.sh, scripts/prepare-docs.sh, README.md
last_verified: 2026-06-17
applies_to: repo, macOS app, token metering adapters, release packaging
related: AGENTS.md, .agents/README.md, .agents/specs/prd.md, .agents/specs/ard.md, README.md
---

# Spill App Build And Run Guide

This page is the agent-facing build/run source of truth. Use it when a Claude,
Codex, or AGY agent needs to build the local app, restart the app, verify token
metering resources, or explain why a source edit did not show up in the running
menu bar app.

## Fast Path For Claude

For normal local app verification:

```bash
./scripts/build-app.sh
open .build/Spill.app
```

If Spill is already running from the repo bundle, restart that process first:

```bash
pgrep -fl ".build/Spill.app/Contents/MacOS/Spill"
kill <pid>
open .build/Spill.app
```

Do not report that an app or adapter change is visible until the correct app
copy has been rebuilt and relaunched.

The detailed token dashboard is bundled as a separate nested helper app:

```text
.build/Spill.app/Contents/Applications/Spill Token Dashboard.app
```

When testing dashboard process behavior, verify that helper bundle exists after
`./scripts/build-app.sh`. Launching the dashboard from the main app should open
that helper, not turn the main menu bar app into a regular foreground app.

## Command Boundaries

| Command | What it proves | What it does not do |
| --- | --- | --- |
| `swift run Spill` | Runs the executable target directly from SwiftPM. | Does not create or run `.build/Spill.app`; not the normal bundled menu bar app path. |
| `swift build` | Compiles the Swift package executable and resources. | Does not create the macOS `.app` bundle, Info.plist, icon, embedded Sparkle framework, or final codesigned app. |
| `./scripts/build-app.sh` | Builds and signs the local `.build/Spill.app` bundle. | Does not update already installed user-level token-metering hook scripts under `~/Library/Application Support/Spill/adapters`. |
| `open .build/Spill.app` | Launches the local bundled app. | Does not terminate an older running copy. If an old process is still running, UI changes may appear missing. |
| `./scripts/package-release.sh` | Builds release ZIP/DMG artifacts from the app bundle. | Requires signing/notarization env only for official Developer ID releases. |

`./scripts/build-app.sh` is the local app bundle source of truth. It runs
`swift build -c release`, creates `.build/Spill.app`, copies the executable,
copies adapter resources into the app bundle, embeds Sparkle, writes
`Info.plist`, generates the icon, creates the nested `Spill Token Dashboard.app`
helper, and signs the helper before signing the main app.

## Menu Bar App Behavior

Spill is an `LSUIElement` menu bar utility. A successful launch normally has no
Dock icon. Check the macOS menu bar for the Spill trigger instead of expecting a
normal app window.

If `open .build/Spill.app` appears to do nothing:

1. Check whether a previous Spill process is still running.
2. Check whether the menu bar trigger is visible.
3. Confirm the process path is `.build/Spill.app/Contents/MacOS/Spill`, not
   `/Applications/Spill.app/Contents/MacOS/Spill`.
4. Use the repo smoke scripts when manual menu bar observation is unreliable.

The nested dashboard helper is a normal foreground app. It should appear in
Command-Tab/Alt-Tab app switchers. Command-Q from the helper should close only
the helper process; the main menu bar Spill process should keep running.

## Restart Loop After Source Changes

Use this loop after Swift UI, store, resource, or app lifecycle changes:

```bash
./scripts/build-app.sh
pgrep -fl ".build/Spill.app/Contents/MacOS/Spill"
kill <pid>
open .build/Spill.app
```

Only kill the repo-local `.build/Spill.app` process unless the user explicitly
asked to restart the installed `/Applications/Spill.app` copy.

Do not rebuild repeatedly while testing Accessibility permissions unless needed.
macOS may treat a newly rebuilt local app bundle as a new permission target.

## Adapter And Hook Resource Copies

Token-metering adapter files have multiple copies on purpose. Keep the copy
being tested separate from the copy being edited.

| Location | Role |
| --- | --- |
| `Sources/Spill/Resources/adapters/<tool>/...` | SwiftPM resource source copied into `.build/Spill.app/Contents/Resources/adapters` by `build-app.sh`. |
| `adapters/<tool>/...` | Repo-level adapter source used for local development and comparison. |
| `scripts/spill-token-metering-setup.mjs` | Public setup helper source copied into the hosted setup package by `scripts/prepare-docs.sh`. |
| `Sources/Spill/Resources/adapters/setup/spill-token-metering-setup.mjs` | Setup helper bundled into the app resources. |
| `Sources/Spill/Resources/adapters/setup/spill-token-metering-stats.mjs` | Read-only local usage stats helper bundled into the app resources and installed beside the setup helper. |
| `~/Library/Application Support/Spill/adapters/<tool>/...` | Installed user-level runtime hook or importer used by Codex, Claude Code, and AGY after setup. |

Rebuilding the app updates the `.build/Spill.app` resource copy. It does not
automatically overwrite the installed user-level hook files in Application
Support. If a hook script changed and the user wants the runtime to use it now,
run the setup helper or installer again after approval.

Default local setup helper:

```bash
node "$HOME/Library/Application Support/Spill/adapters/setup/spill-token-metering-setup.mjs" --apply
```

Public installer path:

```bash
/bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)"
```

When changing adapter behavior, check the active copies before claiming the
runtime is fixed:

```bash
diff -q adapters/claude-code/spill-hook.py Sources/Spill/Resources/adapters/claude-code/spill-hook.py
diff -q adapters/codex/spill-importer.mjs Sources/Spill/Resources/adapters/codex/spill-importer.mjs
```

When changing setup helper behavior, inspect every active setup helper source
instead of assuming they are synchronized:

```bash
diff -q scripts/spill-token-metering-setup.mjs Sources/Spill/Resources/adapters/setup/spill-token-metering-setup.mjs
diff -q adapters/setup/spill-token-metering-setup.mjs Sources/Spill/Resources/adapters/setup/spill-token-metering-setup.mjs
diff -q adapters/setup/spill-token-metering-stats.mjs Sources/Spill/Resources/adapters/setup/spill-token-metering-stats.mjs
diff -q scripts/spill-token-metering-stats.mjs Sources/Spill/Resources/adapters/setup/spill-token-metering-stats.mjs
```

## Token Metering Runtime Facts

The local app imports token usage from an event inbox into its app-owned SQLite
store. The inbox can be empty immediately after a hook ran because the app may
have already imported and removed the queued JSON file.

Important paths:

```text
~/Library/Application Support/Spill/token-metering/events-inbox/
~/Library/Application Support/Spill/token-metering/events.sqlite3
~/Library/Application Support/Spill/token-metering/diagnostics/
```

When the user explicitly asks an agent for `spill`, Spill status, token usage
status, or local usage status, the agent may run the installed read-only status
helper for its current runtime:

```bash
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool <current-tool>
```

Concrete runtime commands:

```bash
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool codex
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool claude
node ~/Library/Application\ Support/Spill/adapters/setup/spill-token-metering-stats.mjs --tool antigravity
```

This command reads the local `token_usage_events` store and prints a self-scoped
aggregate summary with totals, input/output tokens, event count, average and
peak event size, workflow label coverage, model/task/stage breakdowns, token
detail categories, and recent activity. Token detail `unknown` means unavailable
detail attribution, not a guessed input category. It is not a usage event, label
handoff, hook, importer, or proof that the current turn was recorded.

Important tool labels:

| Runtime | Canonical `ai_tool` label |
| --- | --- |
| Codex | `codex` |
| Claude Code | `claude` |
| Antigravity / AGY | `antigravity` |

`agy` is an alias only. Stored events and dashboard filters should use
`antigravity`.

Runtime hook input contracts differ by tool:

- Codex imports exact token-count records from the Codex session importer.
- Claude Code Stop hooks receive a safe payload with `transcript_path`; the
  adapter reads exact numeric usage from the transcript and writes safe events.
- Antigravity/AGY uses the local active importer. The setup helper removes
  managed Spill AGY `PostInvocation` entries so hook command logs cannot be
  mistaken for usage evidence.

Never estimate token usage. If exact runtime usage is not available, write no
usage event. Use local-only diagnostics for support state.

## AGY Evidence Boundaries

Treat AGY setup, label handoff, adapter tests, and real usage evidence as
separate surfaces.

A setup helper `--label antigravity ... --if-absent` permission prompt only
writes short-lived safe label context. It does not contain token counts and must
not be reported as proof that AGY usage was recorded.

These checks are useful but synthetic:

- unit tests and token-metering smoke tests;
- hook config shape or permission allowlist inspection;
- AGY logs that say a hook file was loaded or a command was selected;
- label-context file writes.

They prove setup or adapter behavior only. They do not prove a real AGY turn
exposed exact usage to Spill.

Accepted evidence for real AGY token metering requires a real AGY runtime turn
followed by at least one concrete local side effect:

- an `events-inbox` usage JSON file imported by Spill;
- a new `token_usage_events` row with `ai_tool = antigravity`.
- `antigravity-active-importer-last.json` showing imported exact usage.

If AGY only asks permission for a label command, report that as label-only. Do
not call it fixed.

Do not force dummy tool calls, `list_permissions`, or other hidden user-visible
tool activity as a normal workaround for text-only turns. Such calls may be used
only as an explicitly approved diagnostic scenario, and the result must still be
validated by the real AGY side effects above.

## AGY Active Importer Decision Rules

Use these rules when evaluating proposed AGY metering changes:

| Proposal | Status | Rule |
| --- | --- | --- |
| Add Stop, PostInvocation, or lifecycle hooks | Prohibited | AGY hook command logs create misleading evidence. Use the active importer. |
| Infer labels from tool names, commands, file operations, or I/O patterns | Prohibited | This violates the privacy boundary. Labels must come from trusted safe workflow labels, fixed safe env fields, safe payload labels, or the fallback `uncategorized/summarize`. |
| Fill `token_breakdown` buckets | Conditional | Fill a bucket only when the runtime exposes that exact source count. Otherwise put the exact total in `unknown` and leave inferred buckets at `0`. |
| Retry local event import | Allowed with constraints | Retry may persist only the strict usage event JSON or a safe temporary copy under local Spill token-metering storage. It must not store prompts, payload values, logs, commands, file paths, stack traces, env values, or secrets. |
| Structured diagnostics | Allowed with constraints | Diagnostics may contain fixed error codes, timestamps, booleans, safe labels, model ids, and numeric token counts. Do not store stack traces, permission dumps, raw payload values, paths, logs, commands, env values, run ids, span ids, or secrets. |

## Diagnostics Contract

Diagnostics are support metadata, not usage events. They must never contain
prompts, responses, commands, file paths, transcript paths, transcript content,
repo names, diffs, logs, source content, environment values, secrets, run ids,
or span ids.

AGY diagnostic files:

```text
antigravity-active-importer-last.json
```

Claude diagnostic files:

```text
claude-last-empty.json
claude-last-mismatch.json
claude-last-success.json
```

Use this file to distinguish active importer scan count, parsed exact usage,
duplicates, and imported events without storing raw AGY payload values.

## Verification Commands

Use the narrowest command that proves the changed surface.

| Change surface | Command |
| --- | --- |
| General repo checks | `python3 .agents/scripts/workflow.py verify` |
| Swift package compile or tests | `swift build`, `swift test` |
| Local app bundle | `./scripts/build-app.sh` |
| Runtime app launch smoke | `python3 .agents/scripts/workflow.py runtime-smoke` |
| Token metering queue/adapters | `python3 .agents/scripts/workflow.py token-metering-smoke` |
| Status item click path | `python3 .agents/scripts/workflow.py status-click-smoke` |
| Hosted web portal | Private `taehwandev/Spill-web` repo: `cd web && npm test && npm run build` |

For documentation-only edits, run at least:

```bash
git diff --check
```

Run broader commands only when the changed text describes behavior that must be
proved or when repo-local workflow gates require them.

## Common Failure Modes

- `swift build` passed, but the app did not change: the `.app` bundle was not
  rebuilt with `./scripts/build-app.sh`.
- `./scripts/build-app.sh` passed, but UI did not change: an older Spill process
  is still running or the installed `/Applications` copy is being observed.
- A hook fix works in the repo but not in Claude/AGY/Codex: the installed
  `~/Library/Application Support/Spill/adapters/...` script was not refreshed.
- `events-inbox/` is empty: that may be normal after the app imports queued
  events. Check SQLite and diagnostics before assuming no hook ran.
- AGY shows `empty_stdin`: that can be a normal no-event lifecycle or tool step.
  Do not treat it as missing token usage unless there is also no later success
  diagnostic or no stored usage event for real model calls.
- A run id looks meaningless: that is expected. Run ids are opaque grouping keys,
  not conversation titles or task names.

## Release Packaging

Use release packaging only when the task is about artifacts, distribution,
Sparkle, signing, notarization, or GitHub Releases:

```bash
./scripts/package-release.sh
```

Without Developer ID and notarization settings, release artifacts are ad-hoc
signed and suitable only for local validation or trusted manual sharing.
Official release packaging requires the Developer ID signing secrets and App
Store Connect API-key notarization environment documented in `README.md`.
