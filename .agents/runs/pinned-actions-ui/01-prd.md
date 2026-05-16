# PRD: Pinned Actions UI

Pinned Actions UI turns existing detected menu bar snapshots into a more understandable compact action surface. The feature uses persisted selected item keys as pins, renders pinned items first in the Spill Bar action row, provides a direct pin toggle on every visible action tile, and reports execution results in the panel header.

## Goals

- Make pinned actions visible directly in the panel.
- Allow pinning and unpinning from the action row.
- Keep the panel compact enough for menu bar use.
- Report action success, unavailable, permission, unsupported, and failure states.
- Improve stale action handling by activating the source app when AXPress cannot complete.

## Non-Goals

- Do not add a second menu bar status item.
- Do not scan every normal app menu bar.
- Do not add private APIs or screen capture.
- Do not implement focused-window quick actions in this slice.

## Entry Point

Users open the existing Spill status item. The action row shows pinned menu bar items first, followed by the current display-mode results.

## UX Requirements

1. Each action tile includes the app icon or a fallback short label.
2. Each action tile includes a compact pin toggle.
3. Pinned actions render before unpinned actions.
4. Disabled actions can still be pinned or unpinned.
5. Clicking an enabled action tries the existing Accessibility press path first.
6. If the press path fails and the source bundle identifier is known, Spill activates or opens that app.
7. The header subtitle shows a short success or failure message.
8. Successful action execution dismisses the panel after a short delay.
9. Layout remains inside the panel layout smoke height.

## Success Criteria

- `swift test` passes.
- Panel layout smoke passes.
- Runtime smoke passes.
- Workflow verification passes.
- Roadmap M5-T1 through M5-T3 are marked done.

## Risks

- AX items can become stale between scan and click.
- Some menu bar extras do not expose bundle identifiers.
- Opening a source app is only a fallback, not a guaranteed item-specific command.
