# Closeout: Runtime Smoke Verification

## Shipped

- Added `SPILL_SMOKE_TEST` startup mode.
- Added bundled app runtime smoke script.
- Added `runtime-smoke` workflow command.
- Documented runtime smoke verification in README, workflow docs, review checklist, and release checklist.

## Verified

- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py language-gates`

## Known Risks

- Smoke mode is not a substitute for visual menu bar testing.

## Follow-ups

- Add macOS CI integration.
- Add optional screenshot or Accessibility inspection when a reliable permission setup exists.
