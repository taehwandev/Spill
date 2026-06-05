# Feature Intake

## Feature ID

`ai-token-metering-local-app`

## Request

Build the macOS app side first for AI token metering. The web dashboard is not
useful unless the local app can create and expose token-only usage events. The
first slice must keep all data local, avoid prompts, commands, file paths, logs,
diffs, source content, environment values, and secrets, and avoid any cloud
transfer.

## User Problem

Users need the local app to be the trusted source of usage data. A dashboard with
only manually entered browser data does not prove the real app can measure or
provide token usage.

## Necessity Assessment

- Current direction: yes. Spill already has an AI status strip and local-first
  utility positioning.
- Best owner: Spill should own the local token event store and local bridge
  because it can enforce the token-only contract before any web or cloud view.
- Compact tray fit: yes, if the tray exposes a concise status and entry point
  while the detailed local dashboard opens as a native app window.
- Private API risk: none. Use local files and loopback networking only.
- If not built: the web dashboard remains a disconnected prototype.

Decision: `build`

Reason:

The app-side local bridge is required before cloud sync or production dashboard
work. It can be implemented as a narrow persistence and loopback API slice
without credentials, paid services, private APIs, or content collection.

## Ambiguity Gate

Clarity: `clear`

Unknown classification:

- blocker: none
- researchable: exact UI placement for future panel signal
- assumable: first slice can use an app-owned local store and native app
  dashboard; loopback JSON remains a developer/integration boundary, not the
  user's local dashboard
- out-of-scope: automatic parsing of third-party prompt/session logs

Resolved inputs:

- maintainer: build app-side data first; token counts only; no command/prompt
  collection; local-only before login.
- repo-research: app has provider/store boundaries and Application Support cache
  patterns.
- assumption: the native app can read its own Application Support token store
  directly. Web surfaces are cloud/account views and must not be required for
  local-only users.

## Clarifying Questions

Questions:

- None.

## Target User

AI-heavy Spill users who want the macOS app to produce safe local usage data
before any account or server dashboard exists.

## Proposed Product Shape

The macOS app owns a token-only local event store and presents a native local
dashboard from that store. A loopback bridge may expose the same allowlisted
schema for development and future integrations, but the user's local dashboard
must work without a web workspace, browser storage, account, server, or cloud
sync.

## Constraints

- macOS/public API constraints: use Foundation/Network only; no private APIs.
- permission constraints: no Accessibility or Screen Recording permission
  change for this slice.
- distribution constraints: no credentials, signing changes, or cloud services.
- performance constraints: no polling loop in the app; serve local JSON on
  request and keep writes small.

## Non-goals

- Inspecting unrelated app commands, prompts, responses, files, logs, diffs, or
  terminal output.
- Production auth, Supabase, cloud ingestion, or Vercel API routes.
- Automatic Codex/Claude/Gemini connector parsing in this slice.

## Open Questions

- Which future local integrations will write token counts automatically.

## Decision

Status: `accepted`

Reason:

Proceed with a local app token event store, native local dashboard, and narrow
loopback bridge for development/future integration boundaries. Automatic
tool-specific collection remains a follow-up.
