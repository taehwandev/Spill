# Verification: Configurable Status Modules

## Automated Commands

- Passed: `swift build`
- Passed: `swift test`
- Passed: `python3 .agents/scripts/workflow.py verify`
- Passed: `python3 .agents/scripts/workflow.py run-gates`
- Passed: `python3 .agents/scripts/workflow.py language-gates`
- Passed: `python3 .agents/scripts/workflow.py code-gates`
- Passed: `python3 .agents/scripts/workflow.py runtime-smoke`
- Passed: `python3 .agents/scripts/workflow.py panel-open-smoke`
- Passed: `python3 .agents/scripts/workflow.py panel-layout-smoke`
- Passed: `git diff --check`

## Manual Verification

- Pending: Open Preferences and confirm CPU and memory module controls are visible.
- Pending: Toggle CPU or memory off and confirm the panel omits the disabled meter.
- Pending: Reorder CPU and memory and confirm the panel follows.

## Results

Build, unit tests, workflow gates, and smoke checks passed. Unit verification covered 42 tests.

## Notes

CPU sampling is expected to update shortly after panel open because it requires two samples.
