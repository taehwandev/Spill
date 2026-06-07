# Feature Intake

## Feature ID

`private-usage-upload`

## Request

Define the product requirements for Spill's optional cloud-backed token usage
backup and web aggregate dashboard. The native macOS app must remain fully
usable without login. When users opt in, the app should upload only encrypted,
pre-aggregated usage statistics through a Spill relay API, not directly to the
database or storage provider. Upload should be low-cost and non-realtime:
sealed previous-day buckets are uploaded opportunistically once per day when
the user next uses the Mac, with a manual Sync Now action for explicit flushes.
The web dashboard is the only cloud reader and shows per-device and combined
statistics.

## User Problem

Users want a safe backup and web view for AI usage totals across multiple Macs,
but they do not need realtime sync and they do not want prompts, commands,
source content, local aliases, or raw event logs to leave the device. The cloud
surface must be cheap enough to operate and trustworthy enough to store data
that belongs to users, not to Spill.

## Necessity Assessment

Answer these before writing a detailed PRD:

- Is this feature necessary for current product direction?
  - Yes. It extends local token metering with optional backup and web aggregate
    viewing while preserving local-first behavior.
- Is it better solved by Spill, macOS, or an existing dedicated app?
  - Spill should own it because the app already owns the token-only local store
    and privacy contract.
- Is it small enough for the compact tray?
  - Yes, if the tray only exposes status and Sync Now. Detailed viewing belongs
    in the local dashboard helper and web dashboard.
- Does it require private APIs, fragile behavior, or permissions that harm distribution?
  - No. It requires normal network access, browser auth, deep-link callback,
    Keychain credential storage, and app-level encryption.
- What happens if we do not build it?
  - Users can still use local metering, but they cannot back up aggregate usage
    or compare multiple devices in one web dashboard.

Decision: `build`

Reason: The feature is aligned with local token metering, but must be scoped as
private aggregate upload and web-only viewing, not general bidirectional sync.

## Ambiguity Gate

Use `${AGENTPLAYBOOK_HOME:-$HOME/Documents/KeyFlowVault/AgentPlaybook}/workflows/ambiguity-gate.md` before PRD authoring.

Clarity: `clear`

Unknown classification:

- blocker:
  - None for PRD drafting.
- researchable:
  - Final storage provider and hosting platform belong in ARD.
  - Final E2EE key custody and recovery design belong in ARD.
- assumable:
  - The product can use daily usage buckets for MVP.
  - The user's local timezone at bucket creation defines daily boundaries.
  - Delayed upload by several days is acceptable as long as local sealed buckets
    remain queued and visible.
- out-of-scope:
  - Realtime sync.
  - App-side cloud downloads.
  - Raw event cloud upload.
  - Direct app-to-database writes.

Resolved inputs:

- maintainer:
  - Local dashboard must work without login.
  - Web dashboard is optional and intended for aggregate statistics plus backup.
  - The app must call a Spill relay server, not a database or storage provider
    directly.
  - Cloud upload defaults to once per day plus manual Sync Now.
  - Previous-day data should upload the next time the PC is used, and multi-day
    backlogs such as weekends can upload later in one batch.
  - The app should upload aggregated section/bucket results, not raw events.
  - The web dashboard must treat each PC/device separately, then compute the
    combined view.
  - Web login should complete in the browser and callback to the app.
  - All cloud usage payloads must be end-to-end encrypted in addition to HTTPS.
- repo-research:
  - The global PRD and ARD already define local token metering as token-only,
    content-free, app-owned, and local-first.
  - Future account sync must be separate from local aliases, settings, and
    prompt display preferences.
  - Existing web portal code models planned GitHub/Google auth, connected
    devices, and sync security controls.
- assumption:
  - The first shipped upload mode can be daily-only.
  - Plan-gated shorter intervals can be deferred until billing exists.
  - Server storage can be changed later because clients only call the relay API.

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

- None before PRD authoring.

## Target User

AI-heavy Mac users who want local token metering first, plus optional encrypted
backup and web aggregate statistics across one or more devices.

## Proposed Product Shape

The native app shows local token usage without login. In Settings, users can
connect a web account, enable Private Usage Upload, see last successful upload,
queued sealed buckets, and press Sync Now. The web dashboard shows each linked
device separately, then provides combined account-level totals after browser-side
decryption.

## Constraints

- macOS/public API constraints:
  - Use public APIs, browser auth, deep links, Keychain, and standard networking.
- permission constraints:
  - No Accessibility, Screen Recording, or filesystem expansion is required for
    upload beyond the existing local token store.
- distribution constraints:
  - Local app must remain useful without account creation.
  - Cloud provider changes must not require app updates when the relay API
    contract remains compatible.
- performance constraints:
  - No realtime stream.
  - No upload when local aggregate data has not changed.
  - Upload must batch multiple sealed buckets and tolerate offline/backlog
    periods.

## Non-goals

- Downloading usage data from cloud into the native app.
- Syncing settings, local aliases, prompt preferences, or adapter setup.
- Server-side plaintext aggregate computation.
- Uploading raw events, prompts, responses, commands, file paths, repo names,
  logs, diffs, source content, environment values, or secrets.
- Building billing or plan enforcement in this PRD.

## Open Questions

- ARD must decide E2EE key custody, account recovery, and browser pairing.
- ARD must decide the first relay/storage backend.
- ARD must decide exact upload batch size and retry/backoff limits.

## Decision

Status: `accepted`

Reason: Proceed with a PRD for optional, daily, encrypted, aggregate-only cloud
upload and web-only account dashboard.
