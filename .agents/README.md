# Spill Agent Docs

This folder is the working source of truth for agent-driven implementation.

## Documents

- `specs/prd.md`: Product requirements and scope.
- `specs/ard.md`: Architecture requirements, decisions, constraints, and module boundaries.
- `workflows/implementation.md`: How agents should plan, implement, verify, and ship work.
- `tasks/roadmap.yml`: Structured implementation milestones and acceptance checks.

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
6. Before implementing a feature unit, complete a necessity check.
7. Ask the maintainer concise clarifying questions when intent, scope, value, or feasibility is unclear.
8. Write repository docs, task artifacts, comments, and scripts in English.

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
