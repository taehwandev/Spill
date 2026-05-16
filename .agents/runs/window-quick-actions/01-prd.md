# PRD: Window Quick Actions

Window Quick Actions adds a compact set of focused-window controls to the Spill Bar. The controls live at the front of the existing action row to preserve panel height while adding left half, right half, center, maximize, next display, and restore.

## Goals

- Add useful window commands without a new panel section.
- Use public Accessibility APIs.
- Preserve compact panel layout.
- Store one best-effort previous frame for restore.
- Keep deterministic frame planning testable without Accessibility permission.

## Non-Goals

- Do not add a dedicated window preferences page.
- Do not add private APIs.
- Do not implement tiling layouts beyond the listed quick actions.
- Do not guarantee every app window accepts frame writes.

## User Experience

When Accessibility is trusted and a focused window exists, the ACTIONS row begins with small window controls. Disabled states explain missing permission, missing focused window, one-display next-display limits, or missing restore state through help text.

## Requirements

1. Left and right half fill the active visible screen half.
2. Center preserves the current window size, clamped to the visible screen.
3. Maximize fills the visible screen frame.
4. Next display moves the window to the next visible display when more than one display exists.
5. Restore returns to the last saved frame after a successful non-restore window action.
6. Actions show disabled states when unavailable.
7. Panel layout smoke remains compact.

## Success Criteria

- `swift test` passes.
- Panel layout smoke passes.
- Runtime smoke passes.
- Workflow verification passes.
- Whitespace diff check passes.
