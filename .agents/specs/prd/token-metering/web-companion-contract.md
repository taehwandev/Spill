# Web Companion Contract PRD

## Document Contract

- Status: active
- Audience: product, privacy, security, macOS, web, and QA maintainers
- Purpose: define the shared contract between the public macOS app and hosted web companion
- Source of truth: this document owns cross-repository product and privacy guarantees
- Related: [Spill PRD index](../../prd.md), [Spill ARD](../../ard.md),
  [Private Usage Upload](private-usage-upload.md)

## Repository Boundary

The hosted account portal, dashboard, native relay proxy, and Supabase receiver
live in `taehwandev/moru-web`. This repository documents the native app's shared
contracts and privacy guarantees.

## Connection Requirements

- The web portal is an optional companion for account connection, install
  guidance, device overview, settings, and encrypted aggregate usage statistics.
- The local app remains fully usable when the user never signs in.
- Token monitoring Preferences may show Sign In and Connect for the optional web
  connection. The action is disabled or unavailable when the build has no safe
  configured web connection URL, while local metering remains active.
- Web login completes in the browser and returns to the app through a callback
  or deep link.
- The app receives a write-only device upload credential, not OAuth access or
  refresh tokens.
- Connection opens `/connect-device` with the fixed native callback hints;
  the web dashboard opens `/spill/dashboard`. Both use the configured origin,
  and the native relay is derived from that same origin at
  `/api/private-usage-relay`.
- Existing standard HTTPS configuration for `spill.thdev.app` migrates to
  `getmoru.com`. Missing configuration remains disabled and custom origins keep
  their explicit host and port. Device credentials and encryption keys remain
  environment-scoped and are not cleared by this endpoint migration.

## Dashboard And Freshness Requirements

- The web dashboard shows per-device statistics and combined account totals
  after browser-side decryption.
- Delayed data is labeled as last backed up, not realtime presence.

## Role And Authorization Requirements

- The web portal has two product roles:
  - `admin`: an administrator who can also use all normal user features.
  - `user`: a normal user who can access only their own account, devices,
    settings, and encrypted usage backup surfaces.
- Admin-only navigation, routes, and controls render only for authenticated
  admins and remain hidden while role state is loading or unavailable.
- UI gating is a user-experience constraint only. Every admin action is also
  enforced at the trusted Supabase RLS or Edge Function boundary.
- Normal users cannot reach admin data or mutations through direct URLs,
  developer tools, client payload edits, stale cached role state, or direct
  relay/API calls.
- Role assignment, role changes, user/device administration, and privileged
  mutations are audited without prompts, responses, commands, file paths, logs,
  diffs, source content, secrets, raw token events, or encrypted bucket plaintext.

## Acceptance

- Web portal requirements are documented before implementation work continues.
- Local metering remains available without account connection.
- Admin menus appear only for admins, and normal users are denied direct admin routes.
- RLS and Edge Function authorization deny normal users from admin reads, role
  changes, and privileged mutations when client checks are bypassed.
- Admin audit records capture actor, action, target, result, and timestamp using
  content-free metadata only.

## Verification

- Verify unauthenticated, normal user, admin, loading, stale-role, revoked-role,
  direct-route, direct-API, and write-only device credential cases.
- Verify public documentation does not expose hosted secrets or treat hidden UI
  as authorization.
