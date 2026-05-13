# Closeout: Source Folder Layout

## Shipped

- Moved Swift source files into responsibility folders under `Sources/Spill`.
- Documented the source layout in the global ARD.
- Added a completed run folder for the source layout slice.

## Verified

- `swift build`
- `python3 .agents/scripts/workflow.py docs`
- `python3 .agents/scripts/workflow.py run-gates`
- `python3 .agents/scripts/workflow.py language-gates`

## Known Risks

- External tooling may need path updates if it referenced flat source paths.

## Follow-ups

- Use folder-level write scopes for the single-trigger reset.
- Use folder-level write scopes for panel and provider work.
