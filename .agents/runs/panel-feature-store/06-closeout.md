# Closeout: Panel Feature Store

## Shipped

- Added the first lightweight Feature Store slice for the compact panel.
- Moved panel display item, pinned item, action item, status module, and
  readiness derivation into `PanelStore` / `PanelState`.
- Moved pin/unpin, menu bar action feedback, window action feedback, and status
  detail target state behind typed `PanelAction` events.
- Applied configured panel status module order and enabled state to
  `PanelState` and status refresh requirements.
- Made menu bar action dismiss state cancel-safe when later panel actions occur.
- Clarified Caffeine menu bar tooltip copy so it names the Caffeine chip rather
  than implying the whole status item toggles Caffeine.
- Wired `SpillPanelController` to own the store and pass it into
  `SpillBarView`.
- Kept menu bar action execution results, window action behavior, status
  details, AI details, footer behavior, and panel layout behavior unchanged.
- Added focused state derivation and typed event tests.

## Changed Files

- `.agents/specs/ard.md`
- `.agents/runs/panel-feature-store/00-intake.md`
- `.agents/runs/panel-feature-store/01-prd.md`
- `.agents/runs/panel-feature-store/02-ard.md`
- `.agents/runs/panel-feature-store/03-task-breakdown.yml`
- `.agents/runs/panel-feature-store/04-agent-briefs.md`
- `.agents/runs/panel-feature-store/05-verification.md`
- `.agents/runs/panel-feature-store/06-closeout.md`
- `Sources/Spill/Panel/PanelStore.swift`
- `Sources/Spill/Panel/SpillActionViews.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Tests/SpillTests/PanelStoreTests.swift`

## Verification

- `swift test --filter PanelStoreTests`
- `swift test --filter SpillSettingsTests`
- `swift test --filter MenuBarStatusContentViewTests`
- `git diff --check`
- `swift test`
- `swift build`
- `./scripts/build-app.sh`
- `./scripts/verify-runtime-smoke.sh`
- `./scripts/verify-panel-open-smoke.sh`
- `./scripts/verify-panel-layout-smoke.sh`
- `python3 .agents/scripts/workflow.py verify`

## Residual Risks

- Settings and close buttons still use AppKit bridge callbacks rather than
  store-owned actions. That boundary is intentional until AppKit host adapters
  are split out.
- Manual rapid-click testing of the delayed dismiss path was not performed
  outside store-level regression tests.
- Manual visual inspection outside smoke diagnostics was not performed in this
  slice.

## Follow-up Tasks

- Continue slimming `AppDelegate` after panel state ownership is stable.
- Introduce adapters for focused window movement and AppKit hosts in separate
  slices.

## Docs Updated

- [x] PRD
- [x] ARD
- [ ] roadmap
- [ ] README
