# Verification: Window Quick Actions

## Automated

- Passed: `swift test`
- Passed: `python3 .agents/scripts/workflow.py panel-layout-smoke`
- Passed: `python3 .agents/scripts/workflow.py runtime-smoke`
- Passed: `python3 .agents/scripts/workflow.py verify`
- Passed: `git diff --check`

## Manual

- Pending: with Accessibility permission granted, focus a normal app window and test left, right, center, maximize, next display, and restore.
