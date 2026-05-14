# Detailed PRD: Configurable Status Modules

## PRD Authoring Gate

`00-intake.md` has `Decision: build`, and the MVP scope is clear: configurable ordering and enabled state for compact system meters. Disabled modules must be functionally inactive.

## Summary

Add configuration for compact status modules so users can choose which system meters appear in the panel and in what order. The MVP covers CPU and memory meters because they are the first always-visible system status candidates. Disabled modules must be omitted from the compact status area and skipped by the provider refresh path.

## Goals

- Let users enable or disable compact system status meters.
- Let users reorder compact system status meters.
- Keep disabled modules from running provider refresh work.
- Preserve a compact panel footprint.
- Keep the configuration model extensible for later network, AI, or window modules.

## Non-goals

- No large system dashboard.
- No drag-and-drop reorder UI in the MVP.
- No action icon ordering in this slice.
- No private API or background polling changes.

## User Stories

- As a user, I want to hide CPU or memory when I do not care about that signal.
- As a user, I want memory before CPU if that is the state I check first.
- As a user, I expect disabled modules to stop doing work instead of only disappearing visually.

## UX Requirements

### Entry Point

Preferences includes a `Status Modules` section.

### Layout

The preferences section shows one row per compact system meter. Each row has:

- module name and icon;
- enabled toggle;
- up and down icon buttons for ordering.

The panel `STATUS` section renders enabled meters in the saved order. If every status meter is disabled, the section is hidden.

### States

- loading: existing panel state remains unchanged.
- empty: if all status meters are disabled, the status section is omitted.
- unavailable: enabled modules may show `N/A` when the provider cannot read state.
- permission required: no new permission state is introduced.
- success: enabled modules render in configured order.
- failure: invalid persisted configuration is normalized to the default module list.

## Functional Requirements

1. Persist compact status module order.
2. Persist compact status module enabled state.
3. Normalize persisted order by removing unknown or duplicate module IDs and appending missing known modules.
4. Render enabled status meters in configured order.
5. Skip provider reads for disabled modules.
6. Keep CPU refresh asynchronous so opening the panel does not block the UI.
7. Provide non-drag reorder controls in Preferences.

## Acceptance Criteria

- Preferences can toggle CPU and memory status modules.
- Preferences can move CPU and memory order up and down.
- Disabling CPU prevents the CPU reader from running during status refresh.
- Disabling memory prevents the memory reader from running during status refresh.
- Panel status meters follow the configured order.
- `swift build` and `swift test` pass.
- Workflow, language, and code gates pass.

## Metrics

- perceived latency: panel opens without waiting on CPU sampling.
- reliability: invalid saved module IDs do not break launch.
- resource use: disabled modules do not refresh.

## Rollout

- MVP: CPU and memory compact system meters.
- later: include network, AI, and optional footer status modules after their UX placement is approved.

## References

- `.agents/runs/system-cpu-provider`
- `.agents/runs/system-memory-provider`
- `.agents/runs/provider-refresh-store`
