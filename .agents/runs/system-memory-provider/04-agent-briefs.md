# Agent Briefs: System Memory Provider

## Coordinator Notes

- You are not alone in the codebase.
- Do not revert changes outside the assigned scope.
- Keep the app buildable.
- Report changed files.
- Confirm the feature necessity decision before implementation.
- Do not add CPU, battery, AI, fake values, polling, private APIs, or status item changes.

## Agent A: Product

Goal:

Document a memory-only system provider that adds real status to the compact panel.

Inputs:

- `.agents/runs/system-memory-provider/00-intake.md`
- `.agents/runs/stitch-panel-shell/06-closeout.md`
- `.agents/runs/provider-model-foundation/06-closeout.md`

Output:

- `.agents/runs/system-memory-provider/01-prd.md`

## Agent B: Architecture

Goal:

Define a public-API memory reader, provider mapping, and panel integration.

Inputs:

- `.agents/runs/system-memory-provider/01-prd.md`
- `Sources/Spill/Providers/SpillStatusModels.swift`
- `Sources/Spill/Panel/SpillBarView.swift`

Output:

- `.agents/runs/system-memory-provider/02-ard.md`
- `.agents/runs/system-memory-provider/03-task-breakdown.yml`

## Agent C1: Provider Builder

Goal:

Implement `SystemMemoryProvider` and pure memory status mapping.

Write scope:

- `Sources/Spill/Providers/SystemMemoryProvider.swift`

Do not edit:

- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Accessibility/`

Acceptance:

- Memory status reads through public APIs.
- Mapping handles unavailable data.
- Mapping returns `SpillStatusItem`.

## Agent C2: Panel Builder

Goal:

Render the real memory status in the compact panel.

Write scope:

- `Sources/Spill/Panel/SpillBarView.swift`
- `.agents/design/stitch.md`

Acceptance:

- Status section shows `MEMORY`.
- Existing `ACTIONS` row remains.
- Accessibility remains visible through state and footer.

## Agent C3: Verifier

Goal:

Add tests and run automated verification.

Write scope:

- `Tests/SpillTests/SystemMemoryProviderTests.swift`
- `.agents/runs/system-memory-provider/05-verification.md`
- `.agents/runs/system-memory-provider/06-closeout.md`

Checks:

- memory calculation tests
- build
- tests
- workflow verify
- runtime smoke
- panel-open smoke

Final report:

- findings first
- verification result
- residual risks
