create extension if not exists pgcrypto;

create or replace function public.spill_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.private_usage_accounts (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null unique references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.private_usage_account_memberships (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.private_usage_accounts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint private_usage_account_memberships_role_supported
    check (role in ('admin', 'user')),
  unique (account_id, user_id)
);

create table public.private_usage_devices (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.private_usage_accounts(id) on delete cascade,
  opaque_device_id text not null,
  device_key_fingerprint text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  last_upload_at timestamptz,
  constraint private_usage_devices_opaque_device_id_safe
    check (opaque_device_id ~ '^[A-Za-z0-9._:-]{1,128}$'),
  constraint private_usage_devices_key_fingerprint_safe
    check (device_key_fingerprint is null or device_key_fingerprint ~ '^[A-Za-z0-9._:-]{1,160}$'),
  unique (account_id, opaque_device_id)
);

create table public.private_usage_device_grants (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.private_usage_accounts(id) on delete cascade,
  grant_hash text not null unique,
  device_key_fingerprint text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  constraint private_usage_device_grants_hash_safe
    check (grant_hash ~ '^[a-f0-9]{64}$'),
  constraint private_usage_device_grants_key_fingerprint_safe
    check (device_key_fingerprint is null or device_key_fingerprint ~ '^[A-Za-z0-9._:-]{1,160}$')
);

create table public.private_usage_device_credentials (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.private_usage_accounts(id) on delete cascade,
  device_id uuid not null references public.private_usage_devices(id) on delete cascade,
  credential_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  last_used_at timestamptz,
  constraint private_usage_device_credentials_hash_safe
    check (credential_hash ~ '^[a-f0-9]{64}$')
);

create table public.private_usage_buckets (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.private_usage_accounts(id) on delete cascade,
  device_id uuid not null references public.private_usage_devices(id) on delete cascade,
  bucket_key text not null,
  bucket_kind text not null default 'daily',
  bucket_start_at timestamptz not null,
  bucket_end_at timestamptz not null,
  timezone text not null,
  schema_version integer not null,
  key_version integer not null,
  ciphertext text not null,
  ciphertext_hash text not null,
  created_at timestamptz not null default now(),
  uploaded_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint private_usage_buckets_kind_supported
    check (bucket_kind in ('daily')),
  constraint private_usage_buckets_window_order
    check (bucket_end_at > bucket_start_at),
  constraint private_usage_buckets_schema_version_supported
    check (schema_version between 1 and 99),
  constraint private_usage_buckets_key_version_supported
    check (key_version between 1 and 99),
  constraint private_usage_buckets_ciphertext_size
    check (char_length(ciphertext) between 1 and 262144),
  constraint private_usage_buckets_ciphertext_hash_safe
    check (ciphertext_hash ~ '^[a-f0-9]{64}$'),
  unique (account_id, device_id, bucket_key, schema_version)
);

create table public.private_usage_admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.private_usage_accounts(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  target_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  result text not null,
  reason_code text,
  request_id text,
  created_at timestamptz not null default now(),
  constraint private_usage_admin_audit_action_safe
    check (action ~ '^[a-z][a-z0-9_.:-]{1,80}$'),
  constraint private_usage_admin_audit_result_safe
    check (result in ('created', 'updated', 'denied', 'failed')),
  constraint private_usage_admin_audit_reason_safe
    check (reason_code is null or reason_code ~ '^[a-z][a-z0-9_.:-]{1,80}$'),
  constraint private_usage_admin_audit_request_id_safe
    check (request_id is null or request_id ~ '^[A-Za-z0-9._:-]{1,160}$')
);

create index private_usage_devices_account_idx
  on public.private_usage_devices (account_id, revoked_at);

create index private_usage_account_memberships_user_idx
  on public.private_usage_account_memberships (user_id, account_id);

create index private_usage_account_memberships_admin_idx
  on public.private_usage_account_memberships (account_id, user_id)
  where role = 'admin';

create index private_usage_device_grants_account_expires_idx
  on public.private_usage_device_grants (account_id, expires_at)
  where consumed_at is null;

create index private_usage_device_credentials_device_idx
  on public.private_usage_device_credentials (device_id)
  where revoked_at is null;

create index private_usage_buckets_account_start_idx
  on public.private_usage_buckets (account_id, bucket_start_at desc);

create index private_usage_buckets_device_start_idx
  on public.private_usage_buckets (device_id, bucket_start_at desc);

create index private_usage_admin_audit_logs_account_idx
  on public.private_usage_admin_audit_logs (account_id, created_at desc);

create trigger private_usage_accounts_updated_at
before update on public.private_usage_accounts
for each row execute function public.spill_set_updated_at();

create trigger private_usage_account_memberships_updated_at
before update on public.private_usage_account_memberships
for each row execute function public.spill_set_updated_at();

create trigger private_usage_devices_updated_at
before update on public.private_usage_devices
for each row execute function public.spill_set_updated_at();

create trigger private_usage_buckets_updated_at
before update on public.private_usage_buckets
for each row execute function public.spill_set_updated_at();

alter table public.private_usage_accounts enable row level security;
alter table public.private_usage_account_memberships enable row level security;
alter table public.private_usage_devices enable row level security;
alter table public.private_usage_device_grants enable row level security;
alter table public.private_usage_device_credentials enable row level security;
alter table public.private_usage_buckets enable row level security;
alter table public.private_usage_admin_audit_logs enable row level security;

create or replace function public.private_usage_is_account_admin(
  check_account_id uuid,
  check_user_id uuid
)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.private_usage_account_memberships m
    where m.account_id = check_account_id
      and m.user_id = check_user_id
      and m.role = 'admin'
  );
$$;

create policy "private usage owners can read own account"
on public.private_usage_accounts
for select
using (
  owner_user_id = auth.uid()
  or exists (
    select 1
    from public.private_usage_account_memberships m
    where m.account_id = private_usage_accounts.id
      and m.user_id = auth.uid()
  )
);

create policy "private usage members can read own membership"
on public.private_usage_account_memberships
for select
using (user_id = auth.uid());

create policy "private usage admins can read account memberships"
on public.private_usage_account_memberships
for select
using (public.private_usage_is_account_admin(account_id, auth.uid()));

create policy "private usage owners can read own devices"
on public.private_usage_devices
for select
using (
  exists (
    select 1
    from public.private_usage_accounts a
    where a.id = private_usage_devices.account_id
      and a.owner_user_id = auth.uid()
  )
  or exists (
    select 1
    from public.private_usage_account_memberships m
    where m.account_id = private_usage_devices.account_id
      and m.user_id = auth.uid()
  )
);

create policy "private usage owners can read encrypted buckets"
on public.private_usage_buckets
for select
using (
  exists (
    select 1
    from public.private_usage_accounts a
    where a.id = private_usage_buckets.account_id
      and a.owner_user_id = auth.uid()
  )
  or exists (
    select 1
    from public.private_usage_account_memberships m
    where m.account_id = private_usage_buckets.account_id
      and m.user_id = auth.uid()
  )
);

create policy "private usage admins can read audit logs"
on public.private_usage_admin_audit_logs
for select
using (
  public.private_usage_is_account_admin(account_id, auth.uid())
);
