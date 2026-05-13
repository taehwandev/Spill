# Detailed ARD: Provider Model Foundation

## Architecture Summary

Add a small provider model layer under the Spill app source tree. The layer should contain plain Swift value types for `SpillStatusItem` and `SpillAction`, plus protocols for providers that supply status and action snapshots. The layer should be independent of SwiftUI layout decisions and should not drive any existing UI until a later feature explicitly wires it in.

## Decisions

### D1: Plain Value Models

Decision:

Represent `SpillStatusItem` and `SpillAction` as plain Swift structs, preferably `Identifiable`, `Hashable`, and `Sendable` where their stored properties allow it.

Rationale:

Plain values are easy to diff, test, cache, and pass between provider and UI layers. They also avoid leaking AppKit objects or live closures into view state.

Alternatives considered:

- View-specific models: rejected because they would couple provider work to the current panel layout.
- Provider-specific models only: rejected because each provider would need UI adapter logic.
- Reference types: rejected unless a later executor requires identity beyond stable IDs.

### D2: Protocols Return Snapshots

Decision:

Provider protocols should return snapshots of current status/action values instead of streaming directly into views.

Rationale:

Snapshot reads are easier to test and preserve control over refresh cadence. Streaming can be layered on later if a provider genuinely needs observation.

Alternatives considered:

- Combine publishers or async sequences immediately: deferred until real providers demonstrate the need.
- Direct SwiftUI bindings: rejected because this foundation must not change UI behavior.

### D3: Action Execution Is Separated From Action Description

Decision:

`SpillAction` should describe an action, while execution should live behind a provider or executor protocol.

Rationale:

This keeps `SpillAction` hashable/sendable and avoids storing closures in reusable model values. It also allows permission checks, stale action handling, and error reporting to live near the provider that understands the action.

Alternatives considered:

- Store closures directly on `SpillAction`: rejected because closures complicate equality, sendability, and deterministic testing.
- Model all actions as a single enum: deferred because action domains are still evolving.

### D4: No UI Wiring In This Feature

Decision:

Do not connect the new provider layer to `SpillBarView`, `StatusItemController`, or scanner UI flows in the foundation feature.

Rationale:

The requested scope is foundation only with no UI behavior change. Wiring should be a separate feature with visual and regression verification.

Alternatives considered:

- Wire placeholder data into the panel immediately: rejected because it would create user-visible behavior and broaden risk.

## Modules Affected

- Future source files under a provider/model area such as `Sources/Spill/Providers/` or `Sources/Spill/Models/`.
- Existing source files should remain unchanged for this planning run.
- Later implementation may read from `MenuBarItemSnapshot` when building adapters, but should not modify scanner behavior as part of the foundation.

## New Types / APIs

Implemented files:

- `Sources/Spill/Providers/SpillStatusModels.swift`
- `Sources/Spill/Providers/SpillActionModels.swift`

Implemented contracts:

- `SpillProviderID`
- `SpillStatusItem`
- `SpillStatusState`
- `SpillStatusProvider`
- `SpillAction`
- `SpillActionKind`
- `SpillActionState`
- `SpillActionRole`
- `WindowActionKind`
- `SpillActionProvider`
- `SpillActionHandler`
- `SpillActionResult`

The models are plain `Hashable` and `Sendable` values. Action execution is represented by `SpillActionHandler`, not stored closures.

## Data Flow

```text
future source API -> provider protocol -> plain model snapshot -> future view adapter -> existing/future UI
future user intent -> action ID -> executor/provider -> source API result
```

## Permissions

- Accessibility: not requested by the foundation; future window/menu action providers may require it.
- Screen Recording: not required.
- Network: not required by the foundation; future AI/cloud providers may require network policy.
- File system: not required by the foundation.

## Failure Modes

- Provider read fails.
- Provider is unavailable because a dependency or permission is missing.
- Action ID is stale by execution time.
- Provider returns duplicate IDs.
- Provider returns excessive or unstable ordering.
- Future UI assumes a provider is always fast or always available.

## Performance Notes

- Model creation should be allocation-light and avoid holding large images or AppKit objects.
- Providers should define snapshot reads but should not start timers or polling in the model layer.
- Future providers should cache expensive system or AX reads outside the plain models.
- Stable IDs and priorities should let future views diff without sorting by localized text.

## Test Strategy

### Automated

- `swift build`
- `swift test`
- `python3 .agents/scripts/workflow.py verify`
- `python3 .agents/scripts/workflow.py runtime-smoke`

### Manual

- Launch the app.
- Confirm the existing status item appears.
- Open and close the existing panel.
- Confirm no new sections, labels, prompts, or placeholders appear.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Model types | Builder A | new provider/model file(s) only | yes |
| Provider protocols | Builder B | new provider/protocol file(s) only | yes |
| Compile integration | Builder C | package target and optional local tests | after model/protocol files |
| Verification | Verifier | no source writes except approved test snapshots if any | after buildable branch |

## Risks

- Adding too much domain behavior to the foundation before real providers exist.
- Accidentally wiring models into UI and changing panel behavior.
- Choosing protocol isolation that conflicts with future provider threading.
- Creating action models that cannot represent stale or permission-gated actions cleanly.
