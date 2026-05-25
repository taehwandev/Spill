# Detailed ARD: Spill AI Workflow

## Architecture Summary

Extend the existing local AI status models with a small recommendation layer and
add safe optional actions to the status detail popover. The implementation stays
inside Spill's current provider and panel boundaries: local detection remains in
`LocalAIStatusProvider`, presentation rows remain in `SpillStatusDetailRows`,
and pasteboard-only UI actions remain in SwiftUI/AppKit view code.

## Decisions

### D1: Keep AI Workflow Local To Existing AI Status

Decision: Add next-step recommendations to `LocalAIToolStatus` instead of
creating a new external integration or dashboard source.

Rationale: The current user value gap is "what should I do next?" not another
data source. The existing statuses already know tool kind, running state, model,
version, and source.

Alternatives considered: Query AgentCat or parse private tool logs. Rejected
because the maintainer clarified AgentCat is unrelated and private logs create
privacy and compatibility risk.

### D2: Copy Commands, Do Not Execute Them

Decision: The MVP copies static launch/helper commands to the pasteboard. It
does not run shell commands, open terminal sessions, or automate app launches.

Rationale: Copying is useful, reversible, and avoids shell injection, terminal
automation, permission, and process-lifecycle risk.

Alternatives considered: Execute commands directly from Spill. Rejected for MVP
because it changes side-effect and security scope.

### D3: UI Actions Stay In The Detail Popover

Decision: Keep the AI strip pills visually unchanged and put next actions in the
popover.

Rationale: The compact panel should not become a dashboard or a large command
palette. The detail popover is already the explicit drill-down surface.

## Modules Affected

- `Sources/Spill/Providers/LocalAIStatusProvider.swift`
- `Sources/Spill/Panel/SpillStatusDetailModels.swift`
- `Sources/Spill/Panel/SpillStatusDetailPopover.swift`
- `Sources/Spill/Panel/SpillBarView.swift`
- `Tests/SpillTests/LocalAIStatusProviderTests.swift`
- `Tests/SpillTests/SpillStatusDetailRowsTests.swift`

## New Types / APIs

```swift
struct LocalAIToolActionRecommendation: Hashable, Sendable {
    let title: String
    let detail: String
    let command: String?
}

struct SpillStatusDetailAction: Identifiable {
    let id: String
    let title: String
    let symbolName: String
    let help: String
    let perform: () -> Void
}
```

## Data Flow

```text
LocalAIStatusProvider
  -> LocalAIToolStatus.actionRecommendation
  -> SpillStatusDetailRows
  -> SpillStatusDetailPopover
  -> pasteboard copy action
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: none.
- Network: none added.
- File system: none added.

## Failure Modes

- Tool not installed: no visible AI status, unchanged behavior.
- Tool ready but idle: recommendation shows start command.
- Tool running: recommendation shows continue/inspect command.
- Pasteboard unavailable: action may fail silently at the platform layer for
  MVP; status details remain visible.
- OpenAI configured: no secret values or secret-printing commands are exposed.

## Performance Notes

- No new refresh loop.
- Recommendation mapping is pure and computed from existing in-memory status.
- Pasteboard work only happens on button click.

## Test Strategy

### Automated

- Unit tests for recommendation mapping across ready/running Codex, Claude,
  Antigravity, Ollama, and OpenAI.
- Detail row tests for the `Next` row.
- Secret-safety test ensuring OpenAI recommendations do not include API key
  values.
- Existing AI status store/provider tests remain valid.

### Manual

- Open panel with local AI tools detected.
- Click AI pills and confirm the popover shows a compact `Next` row.
- Click copy-command action and paste into a text field to confirm static command
  text.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Recommendation model | builder | `LocalAIStatusProvider.swift`, tests | No |
| Detail rows | builder | `SpillStatusDetailModels.swift`, tests | After model |
| Popover action | builder | `SpillStatusDetailPopover.swift`, `SpillBarView.swift` | After model |

## Risks

- The first slice does not yet answer path/project usage; that needs a separate
  local journal design.
- Copying commands is less automated than launching tools, but keeps MVP safe and
  reviewable.
