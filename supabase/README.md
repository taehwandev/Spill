# Spill Supabase Setup

This directory contains the first Supabase backend for Private Usage Upload.
The relay stores only encrypted usage buckets and routing metadata. Do not put
Supabase service-role keys, OAuth client secrets, database passwords, or device
credentials in source files.

## Project

- Supabase project ref: `otggbleddlmzamgpqxjm`
- Project URL pattern: `https://<project-ref>.supabase.co`
- Current project URL: `https://otggbleddlmzamgpqxjm.supabase.co`

In the Supabase Dashboard, the Project URL is under:

```text
Project Settings -> API -> Project URL
```

## Local And Vercel Web Env

Create `web/.env.local` locally and set the same values in Vercel Project
Settings. The publishable key is browser-visible, but it should still stay in
environment configuration instead of source.

```bash
VITE_SUPABASE_URL=https://otggbleddlmzamgpqxjm.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=<publishable-or-anon-key>
VITE_SPILL_RELAY_FUNCTION_URL=https://otggbleddlmzamgpqxjm.supabase.co/functions/v1/private-usage-relay
```

## Supabase Function Secrets

Set these in Supabase Dashboard or with the CLI after the project is ready for
remote backend setup. Never commit the actual values and never place these
values in Vercel client environment variables.

```bash
npx supabase secrets set SPILL_WEB_ORIGIN=https://spill.thdev.app
npx supabase secrets set SPILL_ADMIN_EMAIL=<admin-email>
```

Supabase hosted Edge Functions provide `SUPABASE_URL` and the service-role
environment automatically. The service role is server-only and must never be
configured in Vercel, browser env, source files, docs with real values, or
command output. If a local function runner does not provide required Supabase
runtime env, set it only in an ignored local function env file for local
testing.

## OAuth Providers

Configure both providers in:

```text
Supabase Dashboard -> Authentication -> Providers
```

For production, allow:

```text
https://spill.thdev.app
```

For local development, allow:

```text
http://localhost:5173
```

Provider-specific redirect/callback values should come from the Supabase
Dashboard provider configuration. Do not paste OAuth client secrets into this
repository.

## Apply Backend

Run these only when you are ready to mutate the Supabase project:

```bash
npx supabase login
npx supabase link --project-ref otggbleddlmzamgpqxjm
npx supabase db push
npx supabase functions deploy private-usage-relay
```

## Pending Deployment TODO

Use this checklist to track remote setup. Unchecked CLI steps change remote
Supabase state and require explicit approval at execution time.

- [x] In Vercel, add only browser-visible Vite variables:
  `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, and
  `VITE_SPILL_RELAY_FUNCTION_URL`.
- [x] In Supabase Auth, configure the production site URL and local/production
  redirect URLs for `https://spill.thdev.app` and `http://localhost:5173`.
- [x] In Supabase Auth providers, enable GitHub and Google OAuth and enter
  provider client secrets only in the Supabase Dashboard.
- [x] In Supabase Function secrets, set `SPILL_WEB_ORIGIN` and
  `SPILL_ADMIN_EMAIL` with placeholders replaced through the Dashboard or an
  approved CLI command. Do not pass real values through chat.
- [x] Link the local checkout to project `otggbleddlmzamgpqxjm` only when ready:
  `npx supabase link --project-ref otggbleddlmzamgpqxjm`.
- [x] Push migrations only after reviewing schema/RLS impact:
  `npx supabase db push`.
- [x] Deploy the relay after function secrets are configured:
  `npx supabase functions deploy private-usage-relay`.
- [ ] After deployment, test sign-in, `/viewer`, normal-user denial, admin
  access, and one synthetic encrypted upload flow.

The Edge Function has `verify_jwt = false` because it accepts two credential
types:

- Supabase user JWTs for dashboard reads and device grant creation.
- Spill write-only device credentials for encrypted bucket uploads.

The function verifies both credential types itself.

## Device Access Model

Each Mac receives its own write-only device credential after a signed-in user
creates and exchanges a short-lived device grant. Browser dashboard calls use
the Supabase user JWT. Device credentials can upload encrypted buckets only and
must receive `403` from viewer, device list, device revoke, bucket read, grant
creation, and admin routes.

Disconnecting a Mac sets `revoked_at` on the device and its active credentials.
This stops that Mac from uploading without signing the user out of other Macs or
browser sessions.

## Roles And Admin Setup

The web portal uses two MVP roles:

- `admin`: can use normal user features and admin-only management surfaces.
- `user`: can use only their own dashboard, devices, settings, and encrypted
  usage backup surfaces.

Admin menus in the web app are only a UX gate. RLS policies and the
`private-usage-relay` Edge Function must enforce the same permission server-side
for every admin read or mutation.

Before production use:

1. Apply the role/account membership migration.
2. Bootstrap the first admin through an explicit reviewed SQL or trusted
   service-role path.
3. Verify normal users cannot self-assign roles or write directly to membership
   tables.
4. Verify admin-only Edge Function routes return `403` for normal user JWTs and
   write-only device credentials.
5. Verify role changes, device administration, and privileged support actions
   write content-free audit rows.

Never put service-role keys, admin bootstrap secrets, or OAuth client secrets in
the browser, Vercel client env, source files, docs, or command output.
