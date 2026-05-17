# Agent Briefs: Status Performance Optimization

## Builder Brief

Goal: Reduce repeated work in the status and panel paths without changing visible behavior.

Context:

- Runtime sampling showed ImageIO PNG decode and SwiftUI/AppKit layout work.
- CPU status currently uses a two-sample async path with a 0.5 second sleep.
- Status item refresh recreates chip views every tick.
- The worktree contains unrelated Preferences changes. Do not edit or revert them.

Tasks:

1. Add icon data downsampling and decoded image caching.
2. Move CPU previous/current sampling into `SystemStatusStore`.
3. Skip menu bar chip view rebuilds when segments are unchanged.
4. Keep tests focused and run the full suite.

Constraints:

- No new UI.
- No private APIs.
- No new permissions.
- Preserve fallback rendering.

## Verifier Brief

Goal: Confirm behavior remains unchanged and the optimization slice is safe.

Checks:

- `swift test --filter SystemStatusStoreTests`
- `swift test`
- `./scripts/build-app.sh`
- `./scripts/verify-panel-layout-smoke.sh`
- `python3 .agents/scripts/workflow.py verify`
- `git diff --check`

Manual:

- Relaunch the built app.
- Confirm menu bar trigger/status remains visible.
