import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const repoRoot = new URL("../../", import.meta.url);
const emailShapedValue = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i;

function readRepoFile(path: string): string {
  return readFileSync(new URL(path, repoRoot), "utf8");
}

test("private usage schema stores encrypted buckets without plaintext usage columns", () => {
  const migration = readRepoFile("supabase/migrations/202606070001_private_usage_upload.sql");

  assert.match(migration, /create table public\.private_usage_buckets/);
  assert.match(migration, /\bciphertext text not null\b/);
  assert.match(migration, /\bciphertext_hash text not null\b/);
  assert.match(migration, /unique \(account_id, device_id, bucket_key, schema_version\)/);
  assert.match(migration, /alter table public\.private_usage_buckets enable row level security/);
  assert.match(migration, /for select/);

  for (const forbiddenColumn of [
    "input_tokens",
    "output_tokens",
    "total_tokens",
    "token_breakdown",
    "prompt",
    "response",
    "command",
    "file_path",
    "repo_name",
    "branch_name",
    "source_content"
  ]) {
    assert.doesNotMatch(migration, new RegExp(`\\b${forbiddenColumn}\\b`));
  }
});

test("private usage relay has split browser and device credential routes", () => {
  const relay = readRepoFile("supabase/functions/private-usage-relay/index.ts");

  assert.match(relay, /DEVICE_TOKEN_PREFIX = "spill_device_v1_"/);
  assert.match(relay, /handleCreateDeviceGrant/);
  assert.match(relay, /handleExchangeDeviceGrant/);
  assert.match(relay, /handleUploadBuckets/);
  assert.match(relay, /handleListBuckets/);
  assert.match(relay, /handleViewer/);
  assert.match(relay, /SPILL_ADMIN_EMAIL/);
  assert.match(relay, /FORBIDDEN_REQUEST_KEYS/);
  assert.match(relay, /SPILL_WEB_ORIGIN/);
  assert.match(relay, /SUPABASE_SERVICE_ROLE_KEY/);
  assert.doesNotMatch(relay, emailShapedValue);
});

test("private usage schema models server-enforced account roles and audit logs", () => {
  const migration = readRepoFile("supabase/migrations/202606070001_private_usage_upload.sql");

  assert.match(migration, /create table public\.private_usage_account_memberships/);
  assert.match(migration, /role in \('admin', 'user'\)/);
  assert.match(migration, /private_usage_is_account_admin/);
  assert.match(migration, /create table public\.private_usage_admin_audit_logs/);
  assert.match(migration, /alter table public\.private_usage_account_memberships enable row level security/);
  assert.match(migration, /alter table public\.private_usage_admin_audit_logs enable row level security/);
  assert.doesNotMatch(migration, emailShapedValue);
});

test("web environment template exposes names without checked-in values", () => {
  const envExample = readRepoFile("web/.env.example");

  assert.match(envExample, /^VITE_SUPABASE_URL=$/m);
  assert.match(envExample, /^VITE_SUPABASE_PUBLISHABLE_KEY=$/m);
  assert.match(envExample, /^VITE_SPILL_RELAY_FUNCTION_URL=$/m);
  assert.doesNotMatch(envExample, /service_role/i);
  assert.doesNotMatch(envExample, /sb_publishable_/);
});
