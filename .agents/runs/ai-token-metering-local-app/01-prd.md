# Detailed PRD: Local App Token Metering Bridge

## Summary

Spill should make the macOS app the local source and local dashboard for token
metering data before the web cloud dashboard or cloud sync become production
features. The first slice stores token-only usage events locally, displays local
aggregates inside the app, and may expose a loopback-only bridge for development
or future reviewed sync helpers. It must not collect prompts, commands,
responses, file paths, logs, diffs, source content, environment values, or
secrets.

## Goals

- Give the app a durable local usage event store.
- Provide a native app local dashboard that reads the local usage event store.
- Keep the local bridge as an implementation/development boundary, not as the
  user-facing local dashboard dependency.
- Provide a discoverable Preferences/status-menu entry point for local token
  metering.
- Enforce the same safe event schema on app storage and app bridge ingestion.
- Avoid cloud transfer and production credentials.

## Non-goals

- Tool-specific automatic usage extraction from Codex, Claude, Gemini, terminal
  logs, or chat transcripts.
- Any server, Supabase, Vercel API, analytics SDK, billing, or paid model call.
- Turning the compact Spill panel into the dashboard. The local dashboard may be
  a separate Preferences/window surface.

## UX Requirements

### Entry Point

The app starts the local store and bridge automatically unless disabled by
environment. The local dashboard opens inside the app from Preferences and the
status menu; it must not require the web workspace, Vite dev server, or browser
local storage.
The visible menu bar status item opens the existing Spill Panel, and token
metering appears inside that panel's AI section as a compact local summary.

The app Preferences must expose Token Metering status even when no user is
signed in. It must show:

- Local only: active without login, detailed categories stay on this computer.
- Cloud aggregate: requires future login and explicit enablement.
- Cloud detailed: requires a separate future token-only opt-in.

The app menu/status menu may open the local dashboard, but must not imply that
production login, Supabase, or cloud sync is active.

### States

- empty: app dashboard shows zero tokens and explains that no token events have
  been recorded locally yet.
- unavailable: app dashboard shows a local store error without falling back to
  browser storage.
- success: app dashboard reads app-owned local token events.
- failure: bridge rejects malformed or forbidden payloads without persisting
  anything.

## Functional Requirements

1. The app must persist usage events under Application Support.
2. Persisted events must use only the safe event schema already used by the web
   dashboard.
3. A loopback bridge must bind to `127.0.0.1` and never expose a public network
   listener.
4. The bridge must support reading, appending, clearing, and health checks.
5. The bridge must reject forbidden or unknown payload fields.
6. The app dashboard must aggregate totals, task types, token sources, and
   sessions from app-owned local events.
7. Any local bridge payload must not include content-like fields.
8. Preferences and menu entry points must expose token metering status without
   adding any upload path.
9. Menu bar primary click must keep opening the existing Spill Panel.
10. The existing Spill Panel AI section must include a compact token metering
    summary with a detail action to the native local token dashboard.

## Behavior Scenarios

Given the Spill app is running
When the local token dashboard opens
Then it reads token events from the app-owned local store.

Given no events have been recorded
When the local token dashboard opens
Then it shows zero-token empty state inside the app.

Given a local payload contains `prompt`, `command`, `file_path`, `log_body`,
`diff`, or unknown fields
When the app bridge receives it
Then the bridge rejects it and no event is persisted.

Given a user clears local usage from the dashboard
When the local app dashboard is open
Then the app-owned local event store is cleared.

Given a user opens Preferences without signing in
When they inspect Token Metering
Then local-only is shown as active and both cloud modes are shown as future
login/opt-in states with no server transfer active.

## Acceptance Criteria

- Swift model/store tests cover safe events, forbidden fields, corrupted files,
  append, clear, and summaries.
- App starts and stops a loopback-only bridge without crashing if the port is
  unavailable.
- Native app dashboard reads, aggregates, refreshes, and clears app-owned token
  events without a browser or web server.
- The existing Spill Panel AI section shows local token metering without
  replacing the panel.
- Preferences show the local-only/login/cloud-detailed state model from the
  product PRD.
- No cloud service, credential, or server sync is added.

## Rollout

- MVP: app local store, native local dashboard, local bridge boundary, tests.
- Later: tool-specific token counters that write safe events into the app store.

## References

- `.agents/runs/ai-token-metering-web/01-prd.md`
- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
