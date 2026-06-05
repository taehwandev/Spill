# Spill Agent Docs

This folder is the working source of truth for agent-driven implementation.

Repo-local Spill docs define product direction, paths, commands, release policy,
and macOS-specific constraints. Platform-neutral agent behavior lives in the
shared AgentPlaybook checkout at
`~/Documents/KeyFlowVault/AgentPlaybook` by default. If the checkout lives
elsewhere, set `AGENTPLAYBOOK_HOME` to that root.

Use AgentPlaybook `index.md` to load only the smallest relevant common,
workflow, platform, or review cards. Keep only Spill-specific policy here.

## Documents

- `specs/prd.md`: Product requirements and scope.
- `specs/ard.md`: Architecture requirements, decisions, constraints, and module boundaries.
- `workflows/implementation.md`: How agents should plan, implement, verify, and ship work.
- `workflows/ambiguity-gate.md`: Spill-specific ambiguity overlay on the shared AgentPlaybook gate.
- `workflows/persona-review.md`: Spill-specific review overlay on the shared AgentPlaybook review workflow.
- `workflows/release.md`: Release request contract, versioning, tagging, packaging, publication, and closeout steps.
- `checklists/release.md`: Quick release gate that points back to the full release workflow.
- `tasks/roadmap.yml`: Structured implementation milestones and acceptance checks.
- `design/stitch.md`: Stitch project and screen references for UI-scoped work.

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
2. Follow `workflows/implementation.md` for execution order and verification.
3. Keep changes small and milestone-oriented.
4. Prefer public macOS APIs. Accessibility is allowed when explicitly scoped.
5. When a behavior is best-effort, show that clearly in UI and docs.
6. Before writing a feature PRD, complete the intake necessity check and the Spill ambiguity overlay.
7. Follow AgentPlaybook for general agent discipline, editing safety, reviews, and verification policy.
8. Write repository docs, task artifacts, comments, and scripts in English.
9. For UI-scoped work, inspect the Stitch source in `design/stitch.md` before implementing SwiftUI changes.

## Workflow Commands

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

Run bundled app runtime smoke verification:

```bash
python3 .agents/scripts/workflow.py runtime-smoke
```

Run compact panel layout smoke verification:

```bash
python3 .agents/scripts/workflow.py panel-layout-smoke
```

Run local token metering bridge smoke verification:

```bash
python3 .agents/scripts/workflow.py token-metering-smoke
```

Run menu bar status item click smoke verification:

```bash
python3 .agents/scripts/workflow.py status-click-smoke
```

Release from the current repository state:

```bash
sed -n '1,260p' .agents/workflows/release.md
```
