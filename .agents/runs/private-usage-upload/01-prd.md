# Detailed PRD: Private Usage Upload

## PRD Authoring Gate

Do not author this PRD until `00-intake.md` has `Decision: build` and all clarifying questions are resolved. If intent, scope, value, UI behavior, feasibility, permissions, or distribution impact is unclear, return to `00-intake.md`, ask the maintainer, and stop here.

## Summary

Spill should add an optional Private Usage Upload feature for users who want
encrypted backup and web aggregate statistics across devices. The local macOS
dashboard remains fully usable without login. When a user connects an account,
the app uploads only sealed, pre-aggregated, end-to-end encrypted usage buckets
through a Spill relay API. Upload is intentionally non-realtime: the MVP default
is once per day when the user next uses the Mac, plus a manual Sync Now action.
The native app never downloads cloud usage data. The web dashboard is the only
cloud reader and shows per-device and combined totals after browser-side
decryption.

## Resolved Inputs

- maintainer decisions:
  - The feature is backup and aggregate statistics, not bidirectional sync.
  - Users must be able to use local token metering without login.
  - The app must call a Spill relay server, not a database or storage provider
    directly.
  - The app must not download cloud usage data.
  - Upload should default to once per day plus manual Sync Now.
  - Previous-day data should upload the next time the PC is active; multi-day
    backlogs such as weekends can upload later in one batch.
  - Upload payloads should contain aggregated section/bucket results, not raw
    events.
  - The web dashboard must keep device-level views separate and also provide a
    combined account view.
  - Web login should complete in the browser and callback to the app.
  - All cloud usage payloads must be end-to-end encrypted in addition to HTTPS.
  - JWTs are for login and authorization only. They must not be used as E2EE
    data encryption keys.
  - E2EE uses app-held bucket data keys and browser/app local wrapping secrets;
    the relay may store encrypted key envelopes but never plaintext keys.
- repo-researched facts:
  - Spill's existing PRD/ARD define token metering as local-first, token-only,
    and content-free.
  - Future account sync must stay separate from local aliases, local settings,
    adapter setup preferences, and prompt display preferences.
  - The existing web portal preview already models planned GitHub/Google login,
    connected devices, and sync security controls.
- assumptions:
  - MVP bucket boundaries use the user's local timezone at local aggregation
    time and store that timezone with the bucket metadata.
  - ARD will decide exact E2EE key custody, web pairing, and account recovery.
  - ARD will decide the first relay/storage backend.
  - Billing and shorter upload intervals are deferred.

## Goals

- Preserve local-only token metering as the default product mode.
- Provide optional encrypted backup for aggregate usage statistics.
- Provide a web dashboard for per-device and combined account statistics.
- Minimize operating cost by uploading only changed sealed aggregate buckets.
- Avoid realtime infrastructure and repeated calls when data has not changed.
- Keep storage-provider choice behind a relay API so backend changes do not
  require app updates.
- Make it impossible for cloud payloads to contain prompts, responses, commands,
  source content, logs, diffs, file paths, repo names, branch names, environment
  values, secrets, or raw event records.

## Non-goals

- Realtime sync or live monitoring in the web dashboard.
- Downloading cloud usage data into the native app.
- Syncing local aliases, dashboard preferences, adapter setup preferences, or
  prompt display-name policy.
- Uploading raw usage events or per-span event logs.
- Allowing the app to write directly to database, object storage, or vendor SDKs.
- Server-side plaintext aggregate analytics.
- Billing, plan enforcement, or paid multi-device policy in MVP.
- Provider-specific storage implementation details; those belong in ARD.

## User Stories

- As a local-only user, I want token metering to work without an account so I can
  keep all usage data on my Mac.
- As a user who opts in, I want Spill to back up encrypted aggregate usage
  statistics so my totals survive local data loss.
- As a multi-device user, I want the web dashboard to show each PC separately so
  I can understand which machine produced which usage.
- As a multi-device user, I want a combined account total so I can see overall
  AI usage without manually adding device totals.
- As a privacy-conscious user, I want the server to store only encrypted
  aggregate payloads and minimal routing metadata.
- As a maintainer, I want clients to call only the Spill relay API so storage
  providers can change without shipping a new app.
- As an operator, I want upload cadence and idempotent batching to keep cloud
  reads/writes predictable and low.

## UX Requirements

### Entry Point

- Local dashboard:
  - Shows token usage without login.
  - Shows cloud upload as optional and disabled until the user connects an
    account.
- Settings:
  - Contains Connect Web Dashboard.
  - Contains Private Usage Upload enable/disable.
  - Shows last successful upload, queued sealed daily buckets, and next eligible
    upload window.
  - Provides Sync Now for a manual one-time upload attempt.
- Web:
  - Login happens in the browser.
  - Successful login returns to the native app through a callback/deep link that
    grants a write-only device credential.
  - Web dashboard displays linked devices, device status, last upload time, and
    aggregate statistics after browser-side decryption.

### Layout

- Compact Spill panel:
  - Shows a small upload status affordance only when useful, such as Local only,
    Upload queued, Last backup yesterday, or Upload failed.
  - Does not become a cloud dashboard.
- Local dashboard/settings:
  - Shows local usage detail.
  - Shows account connection and upload controls.
  - Shows queued daily buckets and safe retry status.
- Web dashboard:
  - Shows account-level totals.
  - Shows per-device cards or table rows.
  - Shows selected device detail.
  - Shows combined totals by day, tool, model, task type, stage, and token
    direction when those aggregate dimensions are present.
  - Shows "last backed up" timestamps rather than realtime presence claims.

### States

- loading:
  - UI shows stable skeletons or pending state while reading local upload status
    or web dashboard buckets.
- empty:
  - Local app shows no queued upload when no sealed aggregate buckets exist.
  - Web dashboard shows connected account with no uploaded device data.
- unavailable:
  - Local app remains usable when offline or when relay service is unavailable.
  - Web dashboard shows a redacted unavailable state when encrypted buckets
    cannot be fetched.
- permission required:
  - Cloud upload requires explicit account connection and user enablement.
  - No additional macOS privacy permission is required beyond existing local
    token metering storage.
- success:
  - Successful upload records an ack for each uploaded bucket and marks those
    buckets clean locally.
  - Web dashboard can show updated per-device and combined totals after
    decryption.
- failure:
  - Failed upload leaves sealed buckets queued locally.
  - UI shows a redacted failure reason and next retry window.
  - Server or network errors never include payload bodies, prompts, commands,
    paths, logs, or provider internals.

## Functional Requirements

1. Local token metering must remain usable without login.
2. Private Usage Upload must be opt-in.
3. The app must call only Spill-owned relay APIs for cloud upload and auth grant
   exchange.
4. The app must never write directly to the database, object storage, or vendor
   client SDK from production code.
5. The app must not download cloud usage data.
6. Browser login must complete through a provider session and callback to the app
   with a short-lived grant.
7. The app must exchange the grant for a write-only device upload credential.
8. The device upload credential must not authorize dashboard reads or account
   administration.
9. Device upload credentials must be stored in the platform credential store.
10. The local app must aggregate raw events into daily usage buckets before
    upload.
11. Raw usage events must never be uploaded.
12. Daily buckets must be sealed when the local day rolls over.
13. Sealed dirty buckets become eligible for upload on the next active app
    session after the local day closes.
14. The default automatic upload cadence must be daily and opportunistic, not a
    fixed wall-clock global schedule.
15. Upload should wait until the app is running, network is available, and the
    Mac is active enough to perform a small background network operation.
16. Multi-day backlogs must be allowed. If the user does not run the app for a
    weekend or several days, all queued sealed dirty buckets should upload in a
    later batch.
17. Sync Now must trigger one immediate upload attempt for eligible sealed dirty
    buckets.
18. Sync Now may include the current in-progress day only if the UI clearly
    labels it as a partial backup and ARD accepts that behavior. MVP should
    prefer sealed previous-day buckets only.
19. Upload must be idempotent by account, device, bucket key, schema version, and
    ciphertext hash or equivalent idempotency key.
20. Uploading the same unchanged bucket again must be accepted as a no-op.
21. If a bucket changed after a failed upload, the next attempt must upload the
    latest encrypted aggregate for that bucket.
22. Cloud usage payloads must be end-to-end encrypted before leaving the app.
23. HTTPS is required but is not sufficient; application-level payload
    encryption is required.
24. The server may store only minimal routing/index metadata in plaintext, such
    as opaque account id, opaque device id, bucket kind, bucket start, schema
    version, ciphertext hash, and timestamps.
25. The server may store encrypted key envelopes needed for browser-side
    decryption, but must not receive browser/app local wrap secrets or plaintext
    bucket data keys.
26. Plaintext aggregate values, tool totals, model totals, task/stage totals,
    token counts, local aliases, prompts, responses, commands, paths, logs,
    diffs, source content, environment values, and secrets must not be stored by
    the server.
27. Web dashboard reads must be account-authenticated.
28. Web dashboard decryption and account/device aggregation must happen after
    encrypted buckets are fetched by the browser.
29. The web dashboard must distinguish no devices, device connected but no
    upload, upload delayed, upload failed, and successful backup states.
30. Provider/storage backend details must remain behind the relay API.
31. Upload behavior must be observable locally through last success, last
    failure, queued bucket count, next eligible retry, and last acked bucket.

## Behavior Scenarios

### Main Path

Given a user has never signed in
When they open the local token dashboard
Then they can see local usage statistics without account prompts blocking the
dashboard.

Given a user connects the web dashboard from Settings
When browser login succeeds
Then the browser returns a short-lived callback to the app and the app exchanges
it for a write-only device upload credential.

Given local token events were recorded on Monday
When Tuesday begins in the user's local timezone
Then Monday's daily aggregate bucket is sealed and marked dirty if its encrypted
payload differs from the last acknowledged version.

Given a sealed dirty bucket exists
When the user next uses the Mac and the app has network access
Then the app uploads the encrypted bucket through the relay API and marks it
clean only after an ack.

Given the user did not open the Mac for a weekend
When the user next runs Spill with network access
Then the app uploads all queued sealed dirty daily buckets in a bounded batch or
in ordered batches until the backlog is drained.

Given the user presses Sync Now
When eligible sealed dirty buckets exist
Then the app immediately attempts one upload batch and reports success, partial
success, or a redacted failure state.

Given encrypted buckets have uploaded for multiple devices
When the user opens the web dashboard
Then the web dashboard fetches encrypted buckets, decrypts them in the browser,
and shows both per-device and combined totals.

Given a browser has lost its local wrapping secret
When it fetches encrypted buckets and key envelopes
Then the server still cannot decrypt the data, and the web UI shows a
decryption-unavailable state until the user pairs again or uses a future
recovery flow.

### Relevant Edge States

Given no sealed dirty buckets exist
When the automatic daily upload window is reached
Then the app makes no network upload request.

Given a bucket upload fails
When the retry window arrives
Then the app retries with backoff and keeps the bucket queued until an ack is
received.

Given the server receives the same idempotency key and ciphertext hash twice
When processing the second request
Then it returns success without creating duplicate aggregate data.

Given a device credential is used against a read endpoint
When the request reaches the relay API
Then the server rejects the request.

Given the user disables Private Usage Upload
When new local events are recorded
Then the app continues local aggregation but does not upload until the user
re-enables the feature.

Given the web dashboard cannot decrypt a bucket
When rendering the dashboard
Then it shows a device-level decryption failure state without dropping other
devices' valid aggregate data.

Given the user changes timezone
When new daily buckets are created
Then each bucket stores the timezone used for its boundary so the web dashboard
can present dates honestly.

## Acceptance Criteria

- Local token metering works with no account and no network.
- Private Usage Upload is disabled by default.
- Enabling Private Usage Upload requires successful browser login and app
  callback.
- The app stores no OAuth access token or refresh token.
- The app receives only a write-only device upload credential.
- Device upload credentials cannot read dashboard data.
- The app never calls a database or storage provider directly in production
  upload code.
- The automatic upload cadence is daily opportunistic upload of sealed dirty
  buckets.
- A fixed global wall-clock upload time is not required.
- If no local aggregate data changed, no upload request is made.
- Multi-day sealed bucket backlogs upload later without data loss.
- Sync Now performs one explicit upload attempt and updates local upload status.
- Raw events are not present in upload requests.
- Server storage contains no plaintext token totals or breakdown values.
- Server storage contains no prompts, responses, commands, paths, repo names,
  logs, diffs, source content, environment values, secrets, or local aliases.
- Server storage contains no plaintext bucket data keys or browser/app local
  wrap secrets.
- Web dashboard shows per-device data separately.
- Web dashboard shows combined totals computed from decrypted per-device buckets.
- Delayed upload is reflected as "last backed up" or equivalent copy, not
  realtime status.
- End-to-end tests cover login callback, encrypted upload, delayed multi-day
  upload, idempotent re-upload, read denial for device credentials, and web
  browser-side aggregate rendering.

## Metrics

- perceived latency:
  - Local dashboard opens without waiting for network.
  - Sync Now returns a visible status within 2 seconds for local request
    dispatch, even if final network completion continues briefly.
- reliability:
  - Sealed dirty buckets remain queued until acknowledged.
  - Upload backlogs drain without duplicate dashboard totals.
  - Failed device buckets do not block other devices in the web dashboard.
- resource use:
  - No automatic upload when there are no dirty sealed buckets.
  - MVP default target is at most one automatic upload attempt per active device
    per day, excluding retries and explicit Sync Now.
  - Upload batch size and retry limits must be bounded in ARD.

## Rollout

- MVP:
  - Local-only default.
  - Browser login with app callback.
  - Write-only device upload credential.
  - Daily sealed bucket upload.
  - Manual Sync Now.
  - Relay API with idempotent encrypted aggregate upload.
  - Web dashboard per-device and combined aggregate view.
- later:
  - Plan-gated shorter upload intervals.
  - Account key recovery.
  - Device rename/revoke flows.
  - Partial current-day backup, if accepted.
  - Billing for multi-device or higher-frequency upload.

## References

- `.agents/specs/prd.md`
- `.agents/specs/ard.md`
- `.agents/runs/ai-token-metering-web/01-prd.md`
- `web/src/features/webPortal/model/syncSecurityPolicy.ts`
