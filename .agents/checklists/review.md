# Review Checklist

Use this for verifier agents.

## Findings First

List bugs, regressions, and missing tests before summary.

## Product Alignment

- [ ] Matches `.agents/specs/prd.md`.
- [ ] Does not turn Spill into a large dashboard.
- [ ] Does not promise complete hidden menu bar recovery.

## Architecture Alignment

- [ ] Matches `.agents/specs/ard.md`.
- [ ] No private API usage.
- [ ] No giant `NSStatusItem` spacer.
- [ ] Provider logic is separated from view code when applicable.

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
- [ ] `python3 .agents/scripts/workflow.py runtime-smoke` when app startup or lifecycle may be affected
- [ ] Relevant manual checks
- [ ] Residual risks documented
