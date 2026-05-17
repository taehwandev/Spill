# Agent Briefs: Status Trigger Hit Target

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert unrelated work.
- Keep one `NSStatusItem`; do not add spacer or helper status items.
- Preserve direct Caffeine toggle behavior unless the maintainer changes that
  product decision.

## Agent A: Product

Goal:

Define the expected menu bar click behavior when status chips are visible.

PRD authoring gate:

- Confirm `00-intake.md` has `Decision: build`.
- Confirm no unresolved clarifying questions remain.

Inputs:

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/runs/status-trigger-hit-target/00-intake.md`

Output:

- `.agents/runs/status-trigger-hit-target/01-prd.md`

## Agent B: Architecture

Goal:

Define the smallest status item composition change that preserves a panel trigger.

Inputs:

- `.agents/runs/status-trigger-hit-target/01-prd.md`
- `.agents/specs/ard.md`

Output:

- `.agents/runs/status-trigger-hit-target/02-ard.md`
- `.agents/runs/status-trigger-hit-target/03-task-breakdown.yml`

## Agent C1: Builder

Goal:

Add a dedicated trigger chip and hit-test coverage.

Write scope:

- `Sources/Spill/MenuBar/MenuBarStatusSummary.swift`
- `Sources/Spill/MenuBar/MenuBarStatusContentView.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Tests/SpillTests/MenuBarStatusContentViewTests.swift`

Do not edit:

- Panel views.
- Preferences views.
- Release or packaging scripts.

Acceptance:

- Trigger chip appears before status chips.
- Caffeine chip remains directly clickable.
- Tests cover trigger and Caffeine hit regions.

## Agent C2: Verifier

Goal:

Verify click routing, build, smoke, and workflow gates.

Checks:

- `swift test --filter MenuBarStatusContentViewTests`
- `swift test`
- `swift build`
- `./scripts/build-app.sh`
- smoke scripts
- workflow verify
- manual restart and click check
