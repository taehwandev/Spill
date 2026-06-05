# Feature Intake

## Feature ID

`ai-token-metering-web`

## Request

Add an AI token metering product surface for Spill. The core service must measure
token counts only, never commands, prompts, responses, file paths, repo names,
diffs, logs, terminal output, or source content. Unauthenticated users must stay
local-only and see detailed local categorization on the current computer.
Authenticated users can opt in to cloud sync and view a web dashboard, with an
additional option to send safe enum-based task breakdowns for cloud drill-down.
The first implementation slice under `web/` should be treated as the
Vercel-oriented cloud dashboard preview, while local-only usage remains visible
inside the macOS app.

## User Problem

AI-heavy users cannot tell where their token budget is going. Raw total usage is
not enough: they need to distinguish analysis, PRD drafting, code generation,
review, documentation, tests, and context sources such as repo context or tool
output. They also need strong proof that Spill is not collecting the sensitive
content that produced those tokens.

## Necessity Assessment

- Current product direction: yes, if implemented as a separate AI tooling
  dashboard and not as a large native tray panel.
- Best product owner: Spill should own metering for Spill-managed AI calls and
  integrations because it can tag calls at the source without inspecting
  unrelated app content.
- Compact tray fit: the native tray should expose only small status/entry points;
  detailed analysis belongs in local views and the web dashboard.
- Private API or permission risk: none for the first web slice; future macOS
  metering must avoid private APIs and unrelated process/content inspection.
- If not built: users keep seeing raw provider totals without understanding which
  work category or context source consumes tokens.

Decision: `build`

Reason:

The request fits Spill's AI/tooling status direction as a local app dashboard
plus a separate cloud dashboard for signed-in users. The maintainer has
explicitly constrained the product to token-count telemetry only, with local-only
behavior before login and optional cloud sync after login.

## Ambiguity Gate

Use `.agents/workflows/ambiguity-gate.md` before PRD authoring.

Clarity: `clear`

Unknown classification:

- blocker: none
- researchable: exact current package versions for the web workspace
- assumable: first slice can use local fixture data and no real auth/backend
- out-of-scope: collecting raw commands, prompts, responses, file paths, repo
  names, diffs, logs, terminal output, or source content

Resolved inputs:

- maintainer: web lives in `web/`, React is acceptable, Vercel is the deployment
  target, token numbers are the only cloud payload, login gates cloud sync, and
  unauthenticated users remain local-only.
- repo-research: Spill is a compact macOS control tray; current repo has no
  existing web workspace; repo workflow expects run artifacts in
  `.agents/runs/ai-token-metering-web/`.
- assumption: the cloud web preview may start with mock/fixture data before
  adding Supabase, sync APIs, or Mac app upload code. Browser fixture data is
  only for preview/development and must not stand in for the local app
  dashboard.

If clarity is `needs-clarification`, ask only the blocking questions below and stop before writing `01-prd.md`.

## PRD Authoring Gate

If any of the following are unclear, set the decision to `needs-clarification`, ask the maintainer, and stop before writing `01-prd.md`:

- user intent
- expected behavior
- feature value
- UI scope
- feasibility
- permission impact
- distribution impact

Only write the detailed PRD after the maintainer answers and this intake is updated with `Decision: build`.

## Clarifying Questions

Ask the maintainer before PRD authoring if any of these are unclear:

- user intent
- expected behavior
- feature value
- UI scope
- feasibility
- permission or distribution implications

Questions:

- None.

## Target User

Developers and AI-heavy Mac users who want a private, local-first view of token
spend and a cloud dashboard only when they explicitly sign in and enable sync.

## Proposed Product Shape

Spill should show local detailed token attribution on the current computer. The
web dashboard should initially show the account/cloud view: aggregate token
usage, task-type breakdowns, context-source hotspots, model distribution,
latency, and privacy/sync mode. If the user is not signed in, no server sync path
is active. If the user signs in, cloud sync remains controlled by an explicit
setting, and detailed cloud categorization is controlled by a separate opt-in.

## Constraints

- macOS/public API constraints: local token events must come from Spill-owned AI
  call wrappers or explicit integrations; Spill must not inspect unrelated app
  commands or private content.
- permission constraints: no new macOS permissions are required for the web-only
  slice.
- distribution constraints: open-source repo must not contain secrets or
  server-only credentials; Mac App Store/direct distribution implications remain
  future work.
- performance constraints: metering must add minimal overhead and support
  batched sync when enabled.

## Non-goals

- Raw prompt, response, command, file path, repo name, branch name, commit
  message, terminal output, error log, diff, source file, or environment value
  collection.
- Backend deployment, Supabase project provisioning, production auth, Mac app
  upload implementation, and billing.
- Expanding the native macOS panel into a large dashboard.

## Open Questions

- Which exact pricing/cost tables should be used for provider-specific cost
  estimates. This does not block the first local dashboard slice.
- Whether encrypted local labels should ever be synced. Default answer for this
  feature is no.

## Decision

Status: `accepted`

Reason:

Proceed with a PRD/ARD and a first cloud React dashboard preview under `web/`.
Treat backend auth/database and Mac app event upload as follow-up tasks behind
the token-only payload contract. The local app remains the unauthenticated
dashboard; the web preview must not claim to be the local-only product surface.
