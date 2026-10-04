<!-- BEGIN MANAGED TAO AGENT OS POINTER -->
## Tao Agent OS Pointer

Read this repository's `AGENTS.md` first. It contains the active shared
Tao Agent OS routing block and repo-local priority rules. Keep this file thin:
only runtime-specific notes should live here, and shared workflow or skill
guidance must route through `AGENTS.md`.

<!-- END MANAGED TAO AGENT OS POINTER -->

# Claude Instructions

Follow `AGENTS.md` for all shared workflow and Spill project instructions.

Before answering or changing anything related to app builds, app restarts,
release packaging, token-metering adapters, or runtime hook installation, read
`.agents/build-and-run.md`; reuse unchanged guidance already read in the session.

Use the `claude` runtime label for Spill workflow handoff:
`SPILL_AI_TOOL=claude` and `SPILL_TOKEN_USAGE_AI_TOOL=claude`. The canonical
runtime instruction referenced by `AGENTS.md` owns status queries, privacy,
workflow label precedence, and the per-turn fallback with `--if-absent`.
