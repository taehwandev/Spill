# Detailed ARD: Configurable Status Modules

## Architecture Summary

Introduce a small `SpillStatusModule` configuration model for compact system meters. `SpillSettings` persists module order and enabled state. `SystemStatusStore` accepts the enabled module set when refreshing and skips disabled readers. `SpillBarView` renders enabled modules in the configured order, and Preferences exposes toggle plus up/down controls.

## Decisions

### D1: Model compact system meters as explicit modules

Decision: Add a `SpillStatusModule` enum with CPU and memory cases.

Rationale: A typed enum keeps persistence normalization, panel rendering, and provider refresh gates aligned.

Alternatives considered: Store arbitrary provider IDs as strings. That is more flexible but weakens validation before a real provider registry exists.

### D2: Disabled means skipped, not hidden-only

Decision: The store receives enabled modules and only runs readers for enabled modules.

Rationale: The maintainer explicitly expects disabled features to stop functioning, not just disappear.

Alternatives considered: Render filtering only. That would leave invisible providers doing work.

### D3: Keep CPU refresh asynchronous

Decision: Add an async CPU status helper and make the store refresh async.

Rationale: CPU usage requires two samples. Sleeping synchronously on the main actor would make the panel feel sluggish.

Alternatives considered: Synchronous CPU sampling with a short sleep. That conflicts with the compact tray latency goal.

## Modules Affected

- `Sources/Spill/Providers/SpillStatusModule.swift`
- `Sources/Spill/Providers/SystemStatusStore.swift`
- `Sources/Spill/Providers/SystemCPUProvider.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Sources/Spill/Panel/SpillPanelController.swift`
- `Sources/Spill/Preferences/StatusModulesPreferencesSection.swift`
- `Sources/Spill/Preferences/PreferencesView.swift`

## New Types / APIs

- `SpillStatusModule` enum with `cpu` and `memory`.
- `SpillSettings.statusModuleOrder` as an ordered list of modules.
- `SpillSettings.enabledStatusModules` as the enabled module set.
- `SpillSettings.isStatusModuleEnabled`, `setStatusModule`, and `moveStatusModule` helpers.
- `SystemStatusStore.refresh` with an enabled module set parameter.

## Data Flow

```text
Preferences -> SpillSettings order/enabled modules
SpillSettings -> SpillPanelController refresh request
enabled modules -> SystemStatusStore -> enabled provider readers only
SpillSettings order/enabled modules + SystemStatusStore values -> SpillBarView meters
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: not used.
- Network: not used.
- File system: UserDefaults only.

## Failure Modes

- Saved order includes unknown IDs: ignore unknown IDs and append missing known modules.
- Saved enabled list is missing: default all known modules to enabled.
- Enabled provider read fails: show the provider's existing unavailable value.
- Disabled provider accidentally referenced: store keeps disabled values unavailable and the panel filters the module out.

## Performance Notes

- CPU sampling uses async sleep and must not block panel presentation.
- Memory reading remains synchronous and only runs when enabled.
- Settings changes may trigger a refresh only for enabled modules.

## Test Strategy

### Automated

- Settings tests cover persisted order normalization, enabled state, and move behavior.
- Store tests cover CPU integration and disabled-reader skipping.
- Existing CPU and memory provider tests remain unchanged.

### Manual

- Open Preferences, toggle CPU or memory, and confirm the panel status section changes.
- Move CPU or memory up/down and confirm the panel order follows.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Module model and settings | Builder | `SpillStatusModule.swift`, `SpillSettings.swift`, settings tests | Yes |
| Store and panel wiring | Builder | `SystemStatusStore.swift`, `SystemCPUProvider.swift`, `SpillBarView.swift`, `SpillPanelController.swift` | Yes after model |
| Preferences UI | Builder | `StatusModulesPreferencesSection.swift`, `PreferencesView.swift` | Yes after settings API |
| Verification and closeout | Verifier | run verification docs | No |

## Risks

- A future generic provider registry may replace this enum. The enum is intentionally small and can migrate later.
- CPU values update slightly after panel open because sampling is async.
