<!-- BEGIN MANAGED AGENTPLAYBOOK POINTER -->
## AgentPlaybook Pointer

Read this repository's `AGENTS.md` first. It contains the active shared
AgentPlaybook routing block and repo-local priority rules. Keep this file thin:
only runtime-specific notes should live here, and shared workflow or skill
guidance must route through `AGENTS.md`.

<!-- END MANAGED AGENTPLAYBOOK POINTER -->

# Spill Agent Docs

This folder is the Spill-specific source of truth for product direction,
repository commands, verification, and local constraints.

Repo-local Spill docs define product direction, paths, commands, release policy,
and macOS-specific constraints. Platform-neutral agent behavior lives in the
shared AgentPlaybook checkout selected by `AGENTPLAYBOOK_HOME`. Keep personal
absolute checkout paths out of committed repo-local docs. If a future team
pinned checkout is approved, use a repo-relative root such as
`.agents/AgentPlaybook`.

Use AgentPlaybook `index.md` to load only the smallest relevant common,
workflow, platform, or review cards. This repo does not keep local workflow
overlays; keep only Spill-specific policy, commands, specs, and verification
helpers here.

## Documents

- `specs/prd.md`: Product requirements and scope.
- `specs/ard.md`: Architecture requirements, decisions, constraints, and module boundaries.
- `specs/token-history-import.md`: Explicit local token history import requirements and architecture for Codex, Claude Code, and Antigravity/AGY.
- `build-and-run.md`: Agent-facing app build, restart, packaging, adapter resource, and token metering hook verification guide.
- `checklists/release.md`: Spill-specific release checklist used with AgentPlaybook release readiness.
- `tasks/roadmap.yml`: Structured implementation milestones and acceptance checks.
- `design/stitch.md`: Stitch project and screen references for UI-scoped work.
- `templates/`: Feature-run artifact templates.
- `scripts/`: Repo-local verification and smoke-check entry points.

## Current Product Direction

Spill is a compact macOS control tray, not a menu bar hack.

The app should:

- keep one small, visible menu bar trigger;
- show a compact panel under the notch or trigger;
- provide useful system, AI, window, and pinned-action controls;
- use public APIs plus Accessibility where needed;
- remain distributable as an open-source notarized macOS app.

The app should not:

- depend on giant `NSStatusItem` spacers;
- promise to recover every hidden menu bar extra;
- use private frameworks such as SkyLight/CoreGraphics Services;
- grow into a large dashboard.

## Agent Rules

1. Read `specs/prd.md` and `specs/ard.md` before changing product behavior.
2. Follow AgentPlaybook workflow cards for execution order and verification.
3. Keep changes small and milestone-oriented.
4. Prefer public macOS APIs. Accessibility is allowed when explicitly scoped.
5. When a behavior is best-effort, show that clearly in UI and docs.
6. Before writing a feature PRD, complete the intake necessity check and the shared AgentPlaybook ambiguity gate.
7. Follow AgentPlaybook for general agent discipline, editing safety, reviews, and verification policy.
8. Write repository docs, task artifacts, comments, and scripts in English.
9. For UI-scoped work, inspect the Stitch source in `design/stitch.md` before implementing SwiftUI changes.

## Repo Verification Commands

Create a feature run:

```bash
python3 .agents/scripts/workflow.py new-run <feature-id>
```

Verify docs, code gates, and build:

```bash
python3 .agents/scripts/workflow.py verify
```

Run only architectural code gates:

```bash
python3 .agents/scripts/workflow.py code-gates
```

Check feature run completeness and implementation readiness:

```bash
python3 .agents/scripts/workflow.py run-gates
```

Check that repository text content is English-only:

```bash
python3 .agents/scripts/workflow.py language-gates
```

The language gate excludes app-owned localization sources and local generated
output such as `graphify-out/`; it continues to enforce English for repository
documentation, workflow policy, and non-localized source files.

Run bundled app runtime smoke verification:

```bash
python3 .agents/scripts/workflow.py runtime-smoke
```

Run compact panel layout smoke verification:

```bash
python3 .agents/scripts/workflow.py panel-layout-smoke
```

Run local token metering queue smoke verification:

```bash
python3 .agents/scripts/workflow.py token-metering-smoke
```

Run menu bar status item click smoke verification:

```bash
python3 .agents/scripts/workflow.py status-click-smoke
```

Release from the current repository state:

```bash
sed -n '1,220p' "${AGENTPLAYBOOK_HOME}/workflows/skills/release-readiness/SKILL.md"
```

Use `README.md` distribution notes, `VIBEGUARD.md`, and
`checklists/release.md` for Spill-specific release constraints.
