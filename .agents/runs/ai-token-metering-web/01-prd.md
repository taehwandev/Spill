# Detailed PRD: AI Token Metering Web Dashboard

## PRD Authoring Gate

Do not author this PRD until `00-intake.md` has `Decision: build` and all clarifying questions are resolved. If intent, scope, value, UI behavior, feasibility, permissions, or distribution impact is unclear, return to `00-intake.md`, ask the maintainer, and stop here.

## Summary

Spill should add a privacy-preserving AI token metering product surface. The
local macOS app records, aggregates, and displays token counts and safe
categorization locally. Users who do not sign in remain local-only inside the
app. Users who sign in can enable cloud sync and view a web dashboard that
aggregates token counts, cost estimates, latency, model usage, and optional
task/category breakdowns without sending prompts, commands, responses, file
paths, repo names, diffs, logs, terminal output, source content, or environment
values.

## Resolved Inputs

- maintainer decisions:
  - The service is token-count metering, not content collection.
  - Unauthenticated users must be local-only.
  - Authenticated users can use a web dashboard after signup/login.
  - Detailed cloud categorization is optional and still sends only numbers,
    enum labels, timestamps, model names, latencies, and opaque identifiers.
  - Web work should live under `web/` and target Vercel.
  - The local dashboard belongs inside the macOS app.
  - The first web screen should be a login/intro/onboarding page for the cloud
    dashboard, with cloud preview available behind it until auth is implemented.
- repo-researched facts:
  - Spill is a compact macOS control tray and should not become a large native
    dashboard.
  - The repo currently has no JavaScript web workspace.
  - Repo run artifacts live under `.agents/runs/ai-token-metering-web/`.
- assumptions:
  - First web implementation can be a cloud dashboard preview with
    browser-local fixture persistence for development only; it is not the local
    product dashboard.
  - Supabase Auth and Supabase Postgres with RLS remain the preferred future
    auth/database direction, but should not be provisioned in this slice.
  - Cost estimates may use fixture pricing until provider-specific pricing is
    wired through a reviewed data source.

## Goals

- Provide a native local app dashboard for token attribution on the current
  computer.
- Provide a web cloud dashboard shape for signed-in users without raw usage
  content.
- Make local-only behavior explicit before login.
- Make cloud sync and detailed cloud breakdowns explicit opt-in states.
- Show where tokens are spent by task type and token source when safe labels are
  available.
- Preserve open-source trust by designing the payload contract around
  allowlisted numeric and enum fields only.

## Non-goals

- Sending or storing prompts, responses, shell commands, terminal output, source
  files, diffs, file paths, repo names, branch names, commit messages, error log
  bodies, environment values, or secrets.
- Building production Supabase auth/database integration in the first slice.
- Adding Mac app sync/upload code in the first slice.
- Adding paid usage, billing, analytics SDKs, crash-reporting SDKs, or recurring
  infrastructure in the first slice.
- Turning the native Spill panel into a full dashboard.

## User Stories

- As a local-only user, I want to see detailed AI token attribution inside the
  macOS app on my current computer without any server transfer.
- As a signed-in user, I want to opt in to cloud sync so I can review aggregate
  usage from the web.
- As a signed-in user, I want a separate detailed-breakdown option so cloud
  charts can show analysis, PRD, code, review, docs, tests, and debugging
  categories.
- As a privacy-conscious user, I want the product to show exactly which kinds of
  data never leave the device.
- As a maintainer, I want the server/client payload schema to make forbidden
  fields unrepresentable or rejected.

## UX Requirements

### Entry Point

The first web slice opens to a login/intro/onboarding page at the root route.
It should explain installation, account connection, app local-only defaults, and
the token-only privacy contract. The dashboard remains available as the next web
view only as a cloud-dashboard preview until auth/backend are implemented. It
should present controls that represent the future sync modes:

- Local only
- Cloud aggregate
- Cloud detailed

The native macOS app must expose the local dashboard entry point. Opening local
token metering from the app must not require the web workspace or Vite dev
server.

### Layout

The web dashboard should use a dense operational layout, not a marketing hero.
It should include:

- an intro/login view with install command, safe fixed setup prompt, privacy
  contract, and dashboard entry action;
- a glass, pill-shaped top navigation for Overview, Hotspots, Sessions, and
  Settings, matching the maintainer-provided Stitch dashboard HTML direction;
- a prominent sync status card for account/local/cloud state;
- KPI row for total tokens, input tokens, output tokens, estimated cost, and
  average latency;
- stacked or segmented breakdown for task type;
- token source hotspot table;
- session trace showing run/span steps;
- privacy contract panel that distinguishes local detail from cloud-safe fields.
- lower-priority detail sections should be collapsible so the default dashboard
  keeps overview, KPIs, cloud preview status, task breakdown, and hotspots scannable.
- a sync contract side panel/FAB that explains opt-in modes without asking for
  API keys, repository monitoring, prompt personalization, file paths, command
  text, or other content-like inputs.

### States

- loading: show stable skeleton rows or muted loading panels without layout
  shift.
- empty: show zero-token state with local-only status and no cloud charts.
- unavailable: show dashboard shell with local-only mode when auth/sync backend
  is not configured.
- permission required: no macOS permission is required for the web slice; future
  cloud sync requires explicit login and sync opt-in.
- success: charts and tables render aggregate fixture or synced token counts.
- failure: show a redacted error that never includes payload bodies, commands,
  prompts, file paths, or provider error bodies.

## Functional Requirements

1. Local-first mode must be a first-class app state. When not signed in, usage
   stays on the current computer and the web/cloud sync state is disabled.
2. Cloud sync must require authentication and explicit enablement.
3. Cloud detailed breakdown must require a separate opt-in from aggregate sync.
4. The cloud payload contract must allow only:
   - schema version
   - opaque device/project/artifact/run/span identifiers
   - task type enum
   - stage enum
   - model identifier
   - numeric input/output/total tokens
   - numeric token-source breakdown
   - numeric latency
   - timestamp
   - sync mode
5. The cloud payload contract must reject or omit:
   - command
   - prompt
   - response
   - file path
   - repo or branch name
   - commit message
   - terminal output
   - log body
   - diff
   - source content
   - environment value
   - arbitrary extra fields
6. The first `web/` implementation must not require production credentials to
   run locally.
7. The app local dashboard must read from the app-owned local usage store.
   Web fixture data may exist only for cloud preview development; it must not
   replace the local app dashboard contract.
8. UI copy must not imply that production cloud sync exists before backend
   routes and auth are implemented.
9. The intro view may show a fixed setup prompt template, but must not imply
   that real user prompt history is collected, stored, synced, or viewable from
   the web.

## Behavior Scenarios

### Main Path

Given a user opens the web app
When the app loads
Then it shows a login/intro page with install guidance, a fixed safe setup
prompt, privacy contract, and dashboard entry action.

Given a user opens the local dashboard from the macOS app
When the dashboard view loads
Then it shows token totals, task breakdowns, token source hotspots, session
trace, and a local sync state without requiring credentials.

Given a user records token counts in the app local dashboard
When the event is saved
Then only numeric counts, timestamp, latency, model id, opaque ids, and selected
enum labels are persisted in the app-owned local store.

Given a user is not signed in
When they view sync settings
Then the dashboard states that detailed token categorization remains local and no
server transfer is active.

Given a user is signed in and cloud aggregate sync is enabled
When usage events are synced in a future slice
Then the web dashboard can show aggregate totals by day, model, and token
direction.

Given a user is signed in and cloud detailed breakdown is enabled
When safe enum labels and numeric source counts are synced in a future slice
Then the web dashboard can show analysis, PRD, code, review, docs, tests, and
debugging breakdowns without content.

### Relevant Edge States

Given there are zero usage events
When the dashboard renders
Then it shows zero totals and empty chart/table states without implying failure.

Given the backend is unavailable or unconfigured
When the dashboard renders
Then it remains usable with fixture/local-only data and labels cloud sync as
unavailable.

Given an event payload contains a forbidden field such as `command` or `prompt`
When the payload is prepared for cloud sync
Then the field is rejected or omitted before network transfer.

Given a future server receives a payload with unknown fields
When validation runs
Then the request is rejected and no unknown fields are persisted.

Given a user logs out or disables cloud sync
When the state updates
Then future uploads stop and server-derived dashboard state is cleared or
refreshed.

## Acceptance Criteria

- The macOS app contains a local token dashboard that can run without production
  credentials or a web server.
- `web/` contains a cloud dashboard preview that can run locally without
  production credentials.
- `web/` contains a login/intro/onboarding view before the dashboard.
- The UI renders local/sample sync states, token KPIs, task breakdowns, hotspot
  table, session trace, and privacy contract.
- Long detail sections can be collapsed and expanded without hiding the core
  overview.
- The app dashboard can load and clear token-only local events from app storage
  without server transfer.
- The local payload/type model has an allowlist shape for sync-safe usage events.
- Forbidden content fields are not present in fixture event types or dashboard
  display models.
- The PRD, ARD, task breakdown, agent briefs, verification, and closeout artifacts
  are updated for this run.
- No Supabase service-role keys, API secrets, or production environment values
  are added to the repository.

## Metrics

- perceived latency: app local dashboard first paint should feel immediate;
  future synced dashboard should load overview data within one second on warm
  cache.
- reliability: event preparation must deterministically reject forbidden fields.
- resource use: future macOS metering must batch sync and avoid background
  network polling by default.

## Rollout

- MVP:
  - PRD/ARD/task artifacts.
  - macOS app local dashboard backed by the app-owned token store.
  - `web/` cloud dashboard preview with fixture data and privacy-safe event model.
  - Local build/typecheck verification.
- later:
  - Supabase Auth and Postgres schema with RLS.
  - Vercel API route or server boundary for usage-event ingestion.
  - Mac app local SQLite metering and opt-in sync uploader.
  - Local-only detailed native view.
  - Web production deployment.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/workflows/implementation.md`
- `.agents/workflows/ambiguity-gate.md`
- `VIBEGUARD.md`
