# Closeout: Single Trigger Reset

## Shipped

- Removed hidden status item reservation behavior from the trigger architecture.
- Kept one visible fixed-width Spill status item.
- Kept notch geometry for panel layout and detection use.
- Updated workflow code gates to support source folders.

## Changed Files

- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/MenuBar/MenuBarNotchGeometry.swift`
- `.agents/scripts/workflow.py`
- `.agents/runs/single-trigger-reset/`

## Verification

- `swift build`
- `python3 .agents/scripts/workflow.py code-gates`
- `python3 .agents/scripts/workflow.py docs`
- `python3 .agents/scripts/workflow.py run-gates`
- `python3 .agents/scripts/workflow.py language-gates`

## Residual Risks

- macOS can still hide any normal status item when menu bar space is exhausted.
- Manual app smoke testing is still needed on a notched Mac with a crowded menu bar.

## Follow-up Tasks

- Build the compact panel shell.
- Add provider models.
- Add a manual release smoke checklist for notched displays.

## Docs Updated

- PRD: yes.
- ARD: yes.
- roadmap: no.
- README: no.
