# Detailed ARD: Private Usage Upload

## Architecture Summary

Private Usage Upload uses Supabase as the first relay backend, but native and
web clients treat it as a Spill-owned relay API. The macOS app uploads only
sealed, encrypted daily aggregate buckets through a write-only device credential.
The web dashboard signs in with Supabase Auth, fetches encrypted buckets through
the same relay boundary, decrypts in the browser, and computes per-device and
combined totals locally. Supabase Postgres stores only opaque ownership and
routing metadata, credential hashes, idempotency keys, ciphertext, and
ciphertext hashes.

## Decisions

### D1: Supabase Postgres Is The First Cloud Store

Decision:

Use one Supabase project for the MVP cloud relay. Store account/device metadata,
short-lived device grants, write-only credential hashes, and encrypted usage
buckets in Postgres.

Rationale:

The PRD needs OAuth login, account-authenticated dashboard reads, write-only
device upload credentials, unique idempotency keys, and relational ownership
checks. Postgres models these constraints directly, while Supabase gives the
project Auth, Edge Functions, migrations, and RLS in one place.

Alternatives considered:

- Cloudflare D1: lower per-row cost and good Workers integration, but OAuth,
  sessions, and device credential enforcement would be more custom work.
- Neon Postgres: strong Postgres backend, but auth and relay deployment remain
  separate choices.
- Turso/libSQL: good SQLite-style deployment, but less natural for Auth/RLS and
  account/device ownership constraints in this MVP.

### D2: Edge Function Relay Hides The Database

Decision:

Native and browser clients call `private-usage-relay` Edge Function routes. The
native app never calls the Supabase database, Storage, or client SDK directly in
production upload code.

Rationale:

The PRD requires storage-provider flexibility and a hard security boundary. The
relay can verify Supabase Auth sessions, verify write-only device credentials,
reject unsafe request shapes, enforce idempotency, and redact errors before
anything reaches the database.

Alternatives considered:

- Direct Supabase client from the native app: rejected because it leaks provider
  details and makes write-only device credentials harder to enforce.
- Vercel serverless API first: viable later, but Supabase Edge Functions keep
  secrets and database access closer to the first backend.

### D3: Server Stores Ciphertext, Not Usage Values

Decision:

The database stores encrypted bucket payloads as opaque ciphertext plus minimal
metadata: account id, device id, bucket kind, bucket boundaries, timezone,
schema version, key version, ciphertext hash, upload timestamps, and retry
support state.

Rationale:

Server-side plaintext analytics would violate the PRD. Storing ciphertext and
metadata lets the web dashboard fetch per-device buckets and decrypt in the
browser while keeping prompts, responses, commands, paths, logs, source, local
aliases, and token totals out of server storage.

Alternatives considered:

- Server-side aggregate rows by model/tool/task/stage: rejected because it would
  put usage values in server plaintext.
- Raw event upload: rejected by PRD.

### D4: Browser Login Creates A Short-Lived Device Grant

Decision:

The web dashboard creates a short-lived grant after Supabase Auth login. The
native app receives that grant via callback/deep link and exchanges it for a
random write-only device credential. The app stores that credential in the
platform credential store.

Rationale:

The app should not store OAuth access or refresh tokens. A short-lived grant
keeps OAuth in the browser and gives the app only the minimum upload permission.

Alternatives considered:

- Native OAuth session in the app: rejected for MVP because it broadens token
  custody.
- Long-lived browser-generated upload token: rejected because revocation and
  audit are weaker.

### D5: Read And Write Credentials Are Split

Decision:

Supabase Auth sessions can create device grants and read encrypted buckets for
their own account. Device credentials can upload encrypted buckets only; they
cannot read dashboard data, manage devices, or create grants.

Rationale:

This is the central least-privilege requirement in the PRD. It also keeps a
compromised device credential from exposing cloud backups.

Alternatives considered:

- One account token for all app actions: rejected because it would authorize
  reads from the native app.

### D6: Admin Role Is Enforced Server-Side

Decision:

The web portal has two MVP roles: `admin` and `user`. Admins are also normal
users, so admin sessions can use the normal dashboard and settings surfaces.
Normal users can access only their own account, devices, settings, and encrypted
bucket read surfaces. Admin-only menus are rendered only after the browser has
loaded a safe viewer DTO that confirms the authenticated user is an admin, but
that UI check is never the security boundary.

Supabase RLS and the `private-usage-relay` Edge Function must enforce every
admin-only read and mutation. The relay must derive the actor from a verified
Supabase Auth JWT, fetch the role from Postgres using trusted server-side
queries, and return `403` for normal users, stale sessions, revoked admins, and
device credentials.

Rationale:

Admin menus are discoverability and workflow controls, not protection. Direct
URLs, browser developer tools, edited client payloads, stale role cache, and
direct API calls must fail even if the UI accidentally exposes a control.

Implementation requirements:

- Add an account-scoped role table, such as `account_memberships`, with one row
  per account/user and role values limited to `admin` or `user`.
- Add Postgres helper functions for RLS, such as
  `is_account_admin(account_id uuid, actor_id uuid)`.
- Prevent client-side self-assignment. Role creation and role changes must run
  through a trusted bootstrap path, service-role migration, or admin-only Edge
  Function.
- Keep role DTOs minimal. Browser responses may expose only the current viewer's
  role and allowed navigation/action flags, not raw membership rows.
- Add admin audit logging for role changes, user/device administration, and
  future privileged support actions.
- Audit rows must contain content-free metadata only: actor id, account id,
  action, target id, result, reason code, request id, and timestamp.
- Audit rows must not contain prompts, responses, commands, file paths, logs,
  diffs, source content, environment values, secrets, raw token events, bucket
  plaintext, local aliases, or service-role values.

Alternatives considered:

- Client-only role checks: rejected because hiding navigation cannot protect
  data or mutations.
- Role stored only in Supabase Auth app metadata: rejected for MVP because RLS
  and account-scoped checks need a queryable server-side source of truth.
- One global admin flag without account scope: rejected because future account
  or workspace support would make the authorization boundary ambiguous.

## Modules Affected

- `.agents/runs/private-usage-upload/02-ard.md`
- `supabase/config.toml`
- `supabase/migrations/*_private_usage_upload.sql`
- `supabase/functions/private-usage-relay/index.ts`
- `supabase/README.md`
- `web/.env.example`
- `web/test/privateUsageRelayContract.test.ts`

## New Types / APIs

```text
POST /functions/v1/private-usage-relay/device-grants
Authorization: Bearer <supabase-user-jwt>

Request:
{
  "device_key_fingerprint": "opaque_safe_fingerprint"
}

Response:
{
  "grant_code": "short_lived_random_code",
  "expires_in_seconds": 600
}
```

```text
POST /functions/v1/private-usage-relay/exchange-device-grant

Request:
{
  "grant_code": "short_lived_random_code",
  "install_id": "opaque_local_install_id",
  "device_key_fingerprint": "opaque_safe_fingerprint"
}

Response:
{
  "device_id": "opaque_server_device_id",
  "credential": "write_only_random_secret",
  "token_type": "spill_device_v1"
}
```

```text
POST /functions/v1/private-usage-relay/upload-buckets
Authorization: Bearer spill_device_v1_<credential>

Request:
{
  "buckets": [
    {
      "bucket_key": "2026-06-06:daily",
      "bucket_kind": "daily",
      "bucket_start_at": "2026-06-06T00:00:00.000+09:00",
      "bucket_end_at": "2026-06-07T00:00:00.000+09:00",
      "timezone": "Asia/Seoul",
      "schema_version": 1,
      "key_version": 1,
      "ciphertext": "base64-or-jwe-compact",
      "ciphertext_hash": "sha256_hex"
    }
  ]
}
```

```text
GET /functions/v1/private-usage-relay/buckets
Authorization: Bearer <supabase-user-jwt>

Response:
{
  "devices": [...],
  "buckets": [...]
}
```

```text
GET /functions/v1/private-usage-relay/viewer
Authorization: Bearer <supabase-user-jwt>

Response:
{
  "user_id": "authenticated_user_uuid",
  "account_id": "current_account_uuid",
  "role": "admin" | "user",
  "permissions": [
    "usage.read_own",
    "device.manage_own"
  ]
}
```

```text
POST /functions/v1/private-usage-relay/admin/user-roles
Authorization: Bearer <supabase-user-jwt>

Request:
{
  "account_id": "current_account_uuid",
  "target_user_id": "target_user_uuid",
  "role": "admin" | "user"
}

Response:
{
  "updated": true,
  "audit_id": "content_free_audit_row_id"
}
```

## Data Flow

```text
local events -> local daily aggregate -> encrypt on Mac
  -> private-usage-relay upload route
  -> credential hash lookup
  -> encrypted bucket upsert
  -> web dashboard authenticated read
  -> browser-side decrypt
  -> per-device and combined aggregate view
```

## Permissions

- Accessibility: no new permission for cloud upload.
- Screen Recording: not used.
- Network: native app uses network only after explicit account connection and
  Private Usage Upload enablement.
- File system: native app reads local token store and writes local upload ack
  state; no broad filesystem scan is required.
- Supabase service role: Edge Function only. Never browser or app.
- Supabase publishable key: browser-visible and stored only in Vercel/local web
  env, not hardcoded in source.
- Admin role: browser-visible role state is display data only. RLS and Edge
  Functions must re-check admin status server-side for every privileged route.
- Device credential: write-only upload credential. It must receive `403` for
  viewer, bucket read, grant creation, device management, role management, and
  audit routes.

## Failure Modes

- Relay unavailable: app keeps sealed buckets dirty and retries later.
- Grant expired: browser must create a new device grant.
- Device credential revoked: upload returns a redacted forbidden response; app
  shows reconnect required.
- Duplicate upload: relay accepts identical idempotency state as success.
- Changed bucket after failed upload: relay stores the latest ciphertext for the
  same bucket key and schema version.
- Browser decryption failure: web UI marks the affected device bucket failed
  without dropping other devices.
- Unsafe request fields: relay rejects the request before database writes.
- Normal user opens admin URL: UI route guard shows a redacted forbidden state;
  admin data is not fetched.
- Normal user calls admin relay route directly: relay returns `403`.
- Admin role revoked while tab is open: subsequent relay calls return `403`, and
  the web app refreshes viewer state and removes admin navigation.
- Stale cached role state: route guard may be stale, but RLS and relay checks
  still deny privileged reads and mutations.

## Performance Notes

- MVP automatic upload is daily and opportunistic.
- Upload batches should stay bounded; initial limit is 31 daily buckets per
  request.
- Database reads are indexed by account, device, and bucket start.
- Realtime is intentionally not used for MVP.
- Server does not compute aggregate totals, so heavy dashboard aggregation moves
  to browser-side decrypted data.

## Test Strategy

### Automated

- Static schema contract test confirms encrypted bucket tables do not add
  plaintext usage columns.
- Static relay contract test confirms expected env names and route file exist.
- Existing web privacy tests continue to reject content-bearing usage fields.
- Future Edge Function tests should cover grant creation, grant exchange,
  credential revocation, idempotent upload, unsafe field rejection, and read
  denial for device credentials.
- Role/RLS tests should cover unauthenticated access, normal user access,
  admin access, stale admin revocation, direct admin route calls, direct admin
  relay calls, device credential denial on admin routes, and role-change audit
  creation.

### Manual

- In Supabase Dashboard, configure GitHub and Google OAuth providers.
- Set Vercel env for browser-visible Supabase URL and publishable key.
- Set Supabase function secrets for web origin and the first admin bootstrap
  email. Keep the service role server-only in the Supabase Edge Function
  runtime; never configure it in Vercel or browser env.
- Link the Supabase project, push migrations, deploy `private-usage-relay`, and
  run one test grant/upload flow with synthetic encrypted data.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| ARD and backend contract | Codex | `.agents/runs/private-usage-upload/02-ard.md`, `supabase/README.md` | No |
| Database schema | Codex | `supabase/migrations/*_private_usage_upload.sql` | Yes after ARD |
| Relay scaffold | Codex | `supabase/functions/private-usage-relay/index.ts`, `supabase/config.toml` | Yes after ARD |
| Web env contract | Codex | `web/.env.example`, `web/test/privateUsageRelayContract.test.ts` | Yes after ARD |
| Role schema and RLS | Codex | `supabase/migrations/*_private_usage_upload.sql`, Edge Function auth helpers | Yes after ARD |
| Admin audit logging | Codex | `supabase/migrations/*_private_usage_upload.sql`, `supabase/functions/private-usage-relay/index.ts` | Yes after role schema |
| Admin-aware web navigation | Codex | `web/src/features/webPortal/*`, web role tests | Yes after viewer DTO |
| Native upload implementation | Later | `Sources/Spill/TokenMetering/*` | Yes after relay contract |
| Web auth/client implementation | Later | `web/src/features/webPortal/*` | Yes after relay contract |

## Risks

- Browser-side E2EE key custody and recovery are not fully designed in this
  slice; the relay stores ciphertext only, but the UX for account recovery is
  future work.
- Supabase Auth sessions in a static Vite/Vercel app may require a later move to
  server-managed cookies if browser token exposure becomes unacceptable.
- Service role key configuration is operationally sensitive and must stay in
  Supabase function secrets only.
- OAuth redirect URLs must be configured exactly for `https://spill.thdev.app`
  and local development before auth testing.
- The first admin bootstrap path is operationally sensitive. It must be explicit
  and reviewed before production setup so normal users cannot self-promote.
