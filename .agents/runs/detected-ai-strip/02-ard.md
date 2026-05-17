# Detailed ARD: Detected AI Strip

## Architecture Summary

Keep the existing local AI provider and store, but change the provider contract
so it returns only visible statuses. The panel remains a pure renderer of store
state: if the AI status list is empty, no AI section is composed or measured.

## Decisions

### D1: Provider Returns Visible AI Statuses

Decision: `LocalAIStatusProvider.statuses` returns Codex and Ollama only when
they are installed or running, and OpenAI only when local configuration exists.

Rationale: This keeps missing tools from becoming placeholder UI and makes the
provider own detection semantics instead of spreading filtering through the
panel.

Alternatives considered: Keep all three statuses and filter in SwiftUI. Rejected
because report sizing, detail rows, and tests would still need to understand
missing placeholder states.

### D2: Hide Empty AI Section

Decision: `SpillBarView` omits the AI divider and section when the store has no
visible statuses.

Rationale: The compact tray should not reserve space for absent local AI state.

## Modules Affected

- `Sources/Spill/Providers/LocalAIStatusProvider.swift`
- `Sources/Spill/Providers/AIStatusStore.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelContentSizer.swift`
- `Sources/Spill/Panel/SpillPanelContentReport.swift`
- `Sources/Spill/Panel/SpillPanelAccessibilityReport.swift`
- Provider, panel, and report tests

## New Types / APIs

`LocalAIStatusProvider.statuses` accepts environment values, process names, and
installed executable names, then returns the visible `LocalAIToolStatus` values
for the panel.

## Data Flow

```text
environment/processes/executables -> LocalAIStatusProvider -> AIStatusStore -> SpillBarView
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: none.
- Network: no external calls.
- File system: executable existence checks in local command search paths.

## Failure Modes

- `ps` fails: process detection is empty, installed/configured statuses can still render.
- executable lookup fails: installed state is absent, running/configured statuses can still render.
- no signals exist: the panel omits the AI strip.

## Performance Notes

- The initial store value is empty and does not run process detection at app launch.
- Panel refresh keeps using the existing background AI refresh path.
- Executable checks are bounded to known command names and search paths.

## Test Strategy

### Automated

- Provider mapping tests for active, idle, configured, and empty states.
- Store refresh tests for hidden-to-visible transitions.
- Panel content report tests for zero optional AI statuses.
- Layout sizing tests for omitted AI section height.

### Manual

- Open the panel with no detected AI tools and confirm no AI section is visible.
- Open the panel with a detected tool or OpenAI configuration and confirm the compact AI section fits.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Provider semantics | builder | `LocalAIStatusProvider.swift`, provider tests | No |
| Panel optional section | builder | `SpillBarView.swift`, panel reports, panel tests | No |

## Risks

- GUI-launched apps may not inherit shell OpenAI environment variables, so OpenAI may stay hidden unless configuration is visible to the app process.
- Executable path detection is best-effort and may miss unusual install locations.
