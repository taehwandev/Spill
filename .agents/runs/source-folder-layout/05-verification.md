# Verification: Source Folder Layout

## Commands

- `swift build`
- `python3 .agents/scripts/workflow.py docs`
- `python3 .agents/scripts/workflow.py run-gates`
- `python3 .agents/scripts/workflow.py language-gates`

## Manual Checks

- Root `Sources/Spill` contains responsibility folders.
- Swift files are not left in the root source folder.
- No Swift type names were changed.

## Results

- `swift build`: passed.
- `python3 .agents/scripts/workflow.py docs`: passed.
- `python3 .agents/scripts/workflow.py run-gates`: passed.
- `python3 .agents/scripts/workflow.py language-gates`: passed.
- Root `Sources/Spill` has no tracked Swift files; Swift files are grouped into responsibility folders.

## Residual Risks

- External tooling outside SwiftPM may expect the previous flat source layout.
