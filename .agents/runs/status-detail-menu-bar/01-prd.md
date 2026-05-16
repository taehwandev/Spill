# PRD: Status Detail Menu Bar

Status Detail Menu Bar adds two layers to existing system and AI status: a glanceable menu bar summary and click-to-open detail popovers inside the Spill panel. Users can turn individual menu bar values on or off from the detail popovers.

## Goals

- Show selected CPU and memory values directly in the menu bar.
- Keep the existing single Spill status item.
- Preserve icon-only behavior when every menu bar status value is disabled.
- Add detailed readings for status pills.
- Keep OpenAI output secret-safe.

## Non-Goals

- Do not add private APIs.
- Do not add bandwidth, process, or per-core CPU analysis.
- Do not create a separate preferences-only workflow.
- Do not expose environment variable values.

## User Experience

The macOS menu bar trigger can show values beside the system clock area, such as `CPU 20%  MEM 56%`. Clicking the trigger opens the same Spill panel. Clicking a CPU or memory status pill opens a small popover with detail rows and a `Show in menu bar` toggle. AI, GPU, and network details remain panel-only in this slice.

## Requirements

1. CPU and memory have persisted menu bar visibility settings.
2. Default menu bar status values include CPU and memory.
3. Status values refresh without opening the panel.
4. Panel status and AI pills remain compact.
5. Popovers show useful detail rows, including available CPU, available memory, and GPU device availability.
6. AI panel summary remains secret-safe and is not part of the menu bar glance.
7. The panel layout smoke check remains valid.

## Success Criteria

- `swift test` passes.
- Panel layout smoke passes.
- Runtime smoke passes.
- Workflow verification passes.
- Whitespace diff check passes.
