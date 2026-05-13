# Detailed PRD: Example Control Tray

## Summary

The control tray is the first full product slice for the revised Spill direction. It turns the current icon-focused Spill Bar into a compact Mac utility panel with status, AI, pinned action, and window action sections.

## Goals

- Make Spill useful even when menu bar icon recovery is incomplete.
- Keep the UI compact and glanceable.
- Provide immediately useful Mac and AI state.
- Provide a small set of window actions.

## Non-goals

- Build a large dashboard.
- Add third-party cloud integrations.
- Implement hotkeys for every window action.
- Use private APIs.

## User Stories

- As a developer, I want to see memory, CPU, battery, and AI tool state quickly.
- As a Mac user, I want quick access to pinned app/menu actions.
- As a user with many windows, I want a few common window moves without another app.

## UX Requirements

### Entry Point

Click the single Spill menu bar trigger.

### Layout

```text
System: [CPU] [Mem] [Battery] [Network]
AI:     [Codex] [Ollama] [OpenAI]
Apps:   [Pinned icons...]
Window: [Left] [Right] [Center] [Max] [Next]
```

### States

- loading: muted shimmer or small progress indicator
- empty: quiet placeholder
- unavailable: gray pill
- permission required: lock icon with concise label
- success: action closes or shows active state
- failure: inline tooltip/message

## Functional Requirements

1. Render section shells even before all providers are implemented.
2. System status provider returns at least placeholder models.
3. AI status provider returns at least local availability placeholders.
4. Window action row appears disabled until Accessibility is trusted.
5. Pinned action section uses existing selected menu bar items initially.

## Acceptance Criteria

- Panel opens quickly.
- Panel remains compact.
- `swift build` passes.
- No spacer status item exists.
- Missing permissions do not crash the panel.

## Metrics

- perceived latency: panel opens under 1 second
- reliability: no silent click failures
- resource use: status polling is conservative

## Rollout

- MVP: shell UI and placeholders
- later: real providers and action execution

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
