# Detailed ARD: AI Token Metering Web Dashboard

## Architecture Summary

Create a new `web/` React workspace as the first cloud-dashboard intro plus
preview slice. The slice should not provision production auth, database, sync,
or secrets. It owns the intro/login UI, cloud dashboard preview UI, sync-mode
state, and a sync-safe usage event model that only contains numeric counts, enum
labels, timestamps, model names, latencies, and opaque identifiers. The local
dashboard belongs inside the macOS app. Future backend work should use a trusted
server/API boundary before persistence and should keep the same allowlist
contract.

## Decisions

### D1: Add `web/` as a Separate React Workspace

Decision:

Create a new `web/` package for the authenticated cloud dashboard instead of
mixing web code into the SwiftPM macOS app.

Rationale:

The native Spill panel must remain compact, while the app can open a separate
native local dashboard window. The web dashboard is a separate account/cloud
surface and can evolve independently for Vercel deployment.

Alternatives considered:

- Native panel dashboard: rejected because it conflicts with compact tray
  direction. A separate native local dashboard window is allowed for local
  metering.
- Reusing `docs/`: rejected because `docs/` is a static marketing/install site
  and should not own app dashboard state.

### D2: Browser Fixtures Before Backend

Decision:

The first web implementation uses fixture/browser-local data only as a cloud
preview stand-in. It does not own the local dashboard and does not add Supabase
configuration, Vercel API routes, production auth, or Mac app sync upload.

Rationale:

The sensitive boundary is the payload contract. The safest web step is a
reviewable cloud dashboard preview and event model with no credential or
external-state risk.

Alternatives considered:

- Implement full auth/database first: rejected for this slice because it would
  add infrastructure and secret handling before the product contract is reviewed.

### D3: Sync-Safe Event Allowlist

Decision:

Represent cloud sync payloads with an allowlisted `UsageEvent` model. Unknown
fields and forbidden content fields are not part of the type. Runtime sanitizer
helpers should only copy known fields.

Rationale:

Open-source trust requires code-level proof that token metering is not content
collection. TypeScript types alone are not enough for future network boundaries,
so the model should also have an allowlist sanitizer for untrusted/raw inputs.

Alternatives considered:

- Store raw provider usage objects: rejected because provider payloads may
  contain fields that are not safe to sync.
- Hash file names or commands: rejected because the product promise is token
  counts only, not content-derived identifiers.

### D4: Future Auth/DB Direction

Decision:

Use Supabase Auth and Supabase Postgres with Row Level Security as the preferred
future auth/database direction, but keep it out of the first local slice.

Rationale:

The product needs login, account-owned dashboard rows, and open-source-friendly
self-host options. Supabase Auth and Postgres/RLS cover those needs with fewer
custom auth surfaces than a bespoke stack.

Alternatives considered:

- Better Auth + Neon/Postgres: viable later if the project needs more custom
  auth control, but more moving pieces for the first hosted dashboard.
- Client-only local storage: accepted for the unauthenticated local mode, but it
  cannot provide web account dashboard rows across devices.

### D5: Design Direction

Decision:

Use a polished intro/login page before a dense operational dashboard. The intro
page should cover account connection, install guidance, fixed safe setup prompt,
and the privacy contract. The dashboard should follow the maintainer-provided
Stitch HTML visual direction: fixed glass top navigation, sync status hero card,
five-card KPI row, 12-column task/hotspot grid, lower session/privacy panels,
and a sync contract side panel/FAB.

Rationale:

The user needs scanning and comparison, not a marketing page. Cards should be
used for repeated dashboard items only; no nested cards or decorative hero.

Alternatives considered:

- Marketing-only landing page: rejected because the requested first surface must
  start login/onboarding and lead into the usable dashboard.
- Native panel visual reuse: deferred; Stitch can revise design later.
- Reinterpreting the dashboard as a dark left-sidebar admin UI: rejected after
  maintainer review because it does not match the provided dashboard HTML.

### D6: Collapsible Detail Panels

Decision:

Keep overview, KPIs, cloud preview status, task breakdown, and hotspots visible
by default. Render lower-priority detail such as session traces and the full
token-only contract in collapsible panels.

Rationale:

The dashboard can grow quickly as token attribution gets richer. Native
`details`/`summary` panels reduce visual length without changing sync state,
storage, or payload semantics.

## Modules Affected

- `.agents/runs/ai-token-metering-web/`: product, architecture, task, brief,
  verification, and closeout artifacts.
- `web/`: React cloud dashboard preview workspace.
- Swift local dashboard files for the corrected local/web boundary.
- No `docs/` static site files in the first slice.

## New Types / APIs

```ts
type SyncMode = "local_only" | "cloud_aggregate" | "cloud_detailed";

type TaskType =
  | "analysis"
  | "prd_drafting"
  | "code_generation"
  | "code_review"
  | "test_generation"
  | "debugging"
  | "documentation"
  | "release_notes";

type UsageStage =
  | "classify"
  | "plan"
  | "draft"
  | "revise"
  | "implement"
  | "verify"
  | "summarize";

type TokenBreakdown = {
  system: number;
  user: number;
  history: number;
  repo_context: number;
  tool_output: number;
  generated_output: number;
};

type UsageEvent = {
  schema_version: 1;
  device_id: string;
  project_id: string;
  artifact_id: string;
  run_id: string;
  span_id: string;
  task_type: TaskType;
  stage: UsageStage;
  model: string;
  input_tokens: number;
  output_tokens: number;
  total_tokens: number;
  token_breakdown: TokenBreakdown;
  latency_ms: number;
  created_at: string;
  sync_mode: SyncMode;
};
```

## Data Flow

```text
cloud preview fixture or future synced aggregate row
  -> allowlist sanitizer
  -> cloud dashboard view model
  -> React screen
  -> user inspects future sync mode state
```

Future production flow:

```text
Spill macOS AI call wrapper
  -> local token counter and category tag
  -> app-owned local event store and native local dashboard
  -> login + sync setting gate
  -> allowlist payload builder
  -> Vercel/Supabase server boundary
  -> auth + schema validation + RLS
  -> dashboard aggregate queries
```

## Permissions

- Accessibility: none for this web slice.
- Screen Recording: none.
- Network: no production network calls in the web preview slice. Future sync
  requires explicit login and sync opt-in.
- File system: no local file reads in the web slice. The macOS app local
  dashboard reads the app-owned local store.

## Failure Modes

- Web dependencies are missing: local install/build fails; no runtime secret
  impact.
- Cloud preview fixture is empty: dashboard renders zero-token preview state.
- Backend is unconfigured: dashboard labels cloud sync unavailable/not active.
- Raw usage input contains forbidden fields: sanitizer omits them because only
  known allowlist keys are copied.
- Future auth session is stale or logged out: upload path must stop before
  network transfer and clear server-derived state.
- Future server receives unknown fields: route/schema validation must reject.

## Performance Notes

- Dashboard fixture rendering should be client-local and immediate.
- Future synced dashboard should aggregate on the server or database view rather
  than shipping raw event lists for every chart.
- Future macOS uploader should batch events and avoid default background polling.

## Test Strategy

### Automated

- `npm run build` in `web/` for typecheck/build.
- Runtime tests for the sanitizer and development storage adapter:
  load, save, corrupted data, forbidden fields, append rejection, and clear.
- `git diff --check` for docs and web files.
- VibeGuard audit before and after edits.

### Manual

- Run the web dev server and inspect desktop/mobile cloud preview dashboard
  states.
- Confirm the visible UI does not claim production cloud sync is active.
- Confirm no prompt/command/file/log-like fields appear in the sync-safe event
  model, fixtures, or rendered cloud payload examples.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Product docs | coordinator | `.agents/runs/ai-token-metering-web/00-intake.md`, `01-prd.md`, `02-ard.md` | No |
| Task and briefs | coordinator | `.agents/runs/ai-token-metering-web/03-task-breakdown.yml`, `04-agent-briefs.md` | No |
| Web local dashboard | sub-agent builder | `web/**` | Yes, after PRD/ARD contract |
| Verification and closeout | coordinator | `.agents/runs/ai-token-metering-web/05-verification.md`, `06-closeout.md` | No |

## Risks

- A dashboard that says "cloud" too early could imply backend behavior that does
  not exist yet.
- Adding auth/database too soon would introduce secrets and external-state risk.
- TypeScript model names could drift from future Swift event names.
- Token breakdown labels could accidentally become content labels if future code
  accepts free-form strings.
- Package installation can add dependency and lockfile churn.
