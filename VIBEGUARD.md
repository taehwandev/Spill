# Spill VibeGuard Policy

This repo uses VibeGuard as the local safety gate before AI-generated
documentation, code, configuration, dependency, deployment, data, or credential
changes.

Shared rules source:

`/Users/taehwankwon/Documents/KeyFlowVault/AgentPlaybook`

Required command shape:

```bash
npx --yes @taehwandev/vibeguard audit . --rules /Users/taehwankwon/Documents/KeyFlowVault/AgentPlaybook
```

Use `--fix` only for low-risk VibeGuard fixes, then inspect the diff.

## Spill-Specific Guardrails

- Do not print, commit, or place Developer ID, notarization, Sparkle, GitHub,
  Apple, or update-feed secrets in repo files, shell history, logs, or chat.
- Treat pasted secrets as exposed. Do not reuse them for deployment; ask the
  maintainer to rotate and enter replacements through a local provider UI or
  secret-store prompt.
- Ask before production release, notarization, Sparkle appcast publication,
  package signing, credential rotation, or GitHub release mutation.
- Keep external service/status checks explicit, cached, rate-limited, and
  documented. Avoid background network polling by default.
- `.build/`, `DerivedData/`, and packaged artifacts are generated outputs. Do
  not edit or review them as source. If VibeGuard reports generated artifacts,
  confirm the source file and explain the generated-artifact limitation.
- Current VibeGuard scans SwiftPM `.build` artifacts and does not expose an
  ignore-dir setting. `maxFileLines` is raised in `.vibeguard.json` to avoid
  generated-artifact false blocks; use AgentPlaybook review and Spill workflow
  gates to flag oversized source files.
- Spill is a local macOS app. Adding backend services, analytics, paid APIs,
  model calls, telemetry, or recurring infrastructure requires explicit
  maintainer approval.

## Required Closeout

Before finishing, report:

- VibeGuard command and result;
- changed files;
- verification commands and observed results;
- any RED/YELLOW gate and whether it is source risk or generated-artifact noise.
