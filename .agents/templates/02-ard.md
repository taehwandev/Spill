# Detailed ARD: <Feature Name>

## Architecture Summary

One paragraph describing the technical approach.

## Decisions

### D1: <Decision>

Decision:

Rationale:

Alternatives considered:

## Modules Affected

- 

## New Types / APIs

```swift
// Sketch only.
```

## Data Flow

```text
source -> provider -> model -> view -> action result
```

## Settings Ownership And Propagation

Complete this section when a setting or configuration affects more than one owner
or visible surface.

- persistence owner and defaults suite:
- writer:
- same-process readers and observation path:
- cross-process readers:
- notification or IPC transport:
- receiver reload/invalidation behavior:
- update-latency guarantee:
- fallback when a receiver is not running:
- polling, timer, collector, network, or upload impact:

Shared defaults persistence is not sufficient evidence of immediate propagation.
Name the explicit delivery and reload path, or document why reopen/restart/manual
refresh is an accepted product behavior.

## Permissions

- Accessibility:
- Screen Recording:
- Network:
- File system:

## Failure Modes

- 

## Performance Notes

- 

## Test Strategy

### Automated

- 

### Manual

- 

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
|  |  |  |  |

## Risks

- 
