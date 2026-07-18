# Review Checklist

Use this for verifier agents.

## Findings First

List bugs, regressions, and missing tests before summary.

## Commit Review Scope

- [ ] When one dirty worktree will be split into independent commits, review each
  planned commit with its explicit path set instead of treating the union as one
  implementation scope.
- [ ] Inspect the staged diff for each commit again before committing, even when
  the same paths already passed the broader task verification.

## Product Alignment

- [ ] Matches `.agents/specs/prd.md` and every applicable canonical domain PRD linked from it.
- [ ] Does not turn Spill into a large dashboard.
- [ ] Does not promise complete hidden menu bar recovery.

## Architecture Alignment

- [ ] Matches `.agents/specs/ard.md`.
- [ ] No private API usage.
- [ ] No giant `NSStatusItem` spacer.
- [ ] Provider logic is separated from view code when applicable.

## Settings And Cross-Surface Propagation

- [ ] Every changed setting names its persistence owner, defaults/migration, reading processes, propagation transport, refresh trigger, and update-latency contract.
- [ ] AI-related settings explicitly cover Preferences, the compact Spill Panel/general dashboard, the separate AI Token Metering dashboard helper, and the clock-adjacent AI menu-bar glance, with a reason for every `not applicable` surface.
- [ ] Other settings cover every panel, dashboard, helper-app, or menu-bar surface that renders or filters the affected state.
- [ ] Cross-process changes use an explicit notification or IPC plus receiver reload/invalidation; shared defaults alone are not treated as immediate synchronization.
- [ ] Tests and manual checks prove the writer-to-surface path without requiring an undocumented restart, reopen, manual refresh, polling loop, or upload sync.

## macOS Behavior

- [ ] Accessibility permission missing state is handled.
- [ ] Status item remains fixed and compact.
- [ ] App can quit cleanly.
- [ ] Panel opens without blocking.

## Code Quality

- [ ] Changes are scoped.
- [ ] No unrelated refactors.
- [ ] No silent failures.
- [ ] Errors return visible states or messages.

## Verification

- [ ] `swift build`
- [ ] `swift test` when model, provider, or data logic changed
- [ ] `python3 .agents/scripts/workflow.py runtime-smoke` when app startup or lifecycle may be affected
- [ ] Relevant manual checks
- [ ] Residual risks documented
