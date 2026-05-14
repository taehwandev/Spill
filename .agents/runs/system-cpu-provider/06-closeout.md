# Closeout: System CPU Provider

## Shipped

- Added `SystemCPUProvider` backed by public Mach CPU load ticks.
- Added `SystemCPUReading` and `SystemCPUStatus`.
- Added delta-based CPU usage mapping.
- Added unavailable fallback for missing, reversed, or zero-delta samples.
- Added unit tests for normal, active, warning, unavailable, clamped usage, and status item metadata.

## Changed Files

- `.agents/runs/system-cpu-provider/`
- `.agents/tasks/roadmap.yml`
- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Tests/SpillTests/SystemCPUProviderTests.swift`

## Verification

- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py run-gates`
- `python3 .agents/scripts/workflow.py language-gates`
- `python3 .agents/scripts/workflow.py code-gates`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `python3 .agents/scripts/workflow.py panel-layout-smoke`
- `git diff --check`

## Residual Risks

- CPU is not visible in the panel yet.
- CPU sampling may differ from Activity Monitor.
- Future UI placement needs maintainer confirmation before PRD authoring.

## Follow-up Tasks

- Ask the maintainer how CPU should appear in the compact panel before writing the integration PRD.
- Integrate CPU into `SystemStatusStore` after visible placement is approved.
- Decide whether CPU needs a visible refresh cadence.

## Docs Updated

- [x] PRD
- [x] ARD
- [x] roadmap
- [ ] README
