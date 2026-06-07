import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  buildPrivateUsageRelayConfig,
  createPrivateUsageRelayClient,
  findForbiddenRelayPayloadPaths,
  relayPublishableKeyDisplayLabel,
  type EncryptedUsageBucketInput
} from "../src/features/webPortal/model/privateUsageRelay.ts";

const repoRoot = new URL("../../", import.meta.url);

function readRepoFile(path: string): string {
  return readFileSync(new URL(path, repoRoot), "utf8");
}

const safeBucket: EncryptedUsageBucketInput = {
  bucket_key: "2026-06-06:daily",
  bucket_kind: "daily",
  bucket_start_at: "2026-06-06T00:00:00.000Z",
  bucket_end_at: "2026-06-07T00:00:00.000Z",
  timezone: "Asia/Seoul",
  schema_version: 1,
  key_version: 1,
  ciphertext: "sealed_ciphertext_preview",
  ciphertext_hash: "a".repeat(64)
};

test("private usage relay config defaults to the Spill Supabase project", () => {
  const config = buildPrivateUsageRelayConfig({});

  assert.equal(config.status, "missing");
  assert.equal(config.projectRef, "otggbleddlmzamgpqxjm");
  assert.equal(config.supabaseUrl, "https://otggbleddlmzamgpqxjm.supabase.co");
  assert.equal(
    config.relayFunctionUrl,
    "https://otggbleddlmzamgpqxjm.supabase.co/functions/v1/private-usage-relay"
  );
  assert.deepEqual(config.missingKeys, ["VITE_SUPABASE_PUBLISHABLE_KEY"]);
});

test("private usage relay config does not retain publishable key values", () => {
  const config = buildPrivateUsageRelayConfig({
    VITE_SUPABASE_PUBLISHABLE_KEY: "publishable_key_preview"
  });

  assert.equal(config.status, "configured");
  assert.equal(config.hasPublishableKey, true);
  assert.equal(JSON.stringify(config).includes("publishable_key_preview"), false);
});

test("private usage relay display labels do not expose env variable names", () => {
  const missingConfig = buildPrivateUsageRelayConfig({});
  const readyConfig = buildPrivateUsageRelayConfig({
    VITE_SUPABASE_PUBLISHABLE_KEY: "publishable_key_preview"
  });

  assert.equal(
    relayPublishableKeyDisplayLabel(missingConfig),
    "Public browser key is not configured"
  );
  assert.equal(
    relayPublishableKeyDisplayLabel(readyConfig),
    "Public browser key present"
  );
  assert.equal(relayPublishableKeyDisplayLabel(missingConfig).includes("VITE_"), false);
});

test("settings UI does not render private usage backend readiness internals", () => {
  const settingsScreen = readRepoFile("web/src/features/webPortal/screens/SettingsScreen.tsx");
  const settingsBlocks = readRepoFile("web/src/features/webPortal/blocks/SettingsBlocks.tsx");
  const settingsPage = readRepoFile("web/src/features/webPortal/pages/SettingsPage.tsx");
  const webPortal = readRepoFile("web/src/features/webPortal/WebPortal.tsx");
  const renderSurface = [settingsScreen, settingsBlocks, settingsPage, webPortal].join("\n");

  for (const internalText of [
    "Encrypted Cloud Backup",
    "Private Usage Relay",
    "RelayBackendBlock",
    "Supabase",
    "Relay Function",
    "otggbleddlmzamgpqxjm",
    "supabase.co",
    "VITE_"
  ]) {
    assert.equal(renderSurface.includes(internalText), false);
  }
});

test("private usage relay rejects content-like nested fields before fetch", async () => {
  let called = false;
  const client = createPrivateUsageRelayClient({
    relayFunctionUrl: "https://otggbleddlmzamgpqxjm.supabase.co/functions/v1/private-usage-relay",
    fetchImpl: async () => {
      called = true;
      return new Response("{}");
    }
  });

  const result = await client.uploadBuckets("spill_device_v1_preview", {
    buckets: [
      {
        ...safeBucket,
        total_tokens: 100
      } as EncryptedUsageBucketInput
    ]
  });

  assert.equal(result.ok, false);
  if (result.ok) {
    throw new Error("expected unsafe request rejection");
  }

  assert.equal(result.error, "unsafe_request");
  assert.equal(result.status, 0);
  assert.equal(called, false);
  assert.deepEqual(
    findForbiddenRelayPayloadPaths({ buckets: [{ token_breakdown: { unknown: 1 } }] }),
    ["buckets[0].token_breakdown"]
  );
});

test("private usage relay sends encrypted buckets through the write-only route", async () => {
  const seen: {
    body?: unknown;
    headers?: Headers;
    method?: string;
    url?: string;
  } = {};
  const client = createPrivateUsageRelayClient({
    relayFunctionUrl: "https://otggbleddlmzamgpqxjm.supabase.co/functions/v1/private-usage-relay",
    fetchImpl: async (input, init) => {
      seen.url = String(input);
      seen.method = init?.method;
      seen.headers = new Headers(init?.headers);
      seen.body = init?.body ? JSON.parse(String(init.body)) : undefined;

      return new Response(
        JSON.stringify({
          accepted: 1,
          uploaded_at: "2026-06-07T00:00:00.000Z"
        }),
        {
          headers: {
            "Content-Type": "application/json"
          },
          status: 200
        }
      );
    }
  });

  const result = await client.uploadBuckets("spill_device_v1_preview", {
    buckets: [safeBucket]
  });

  assert.equal(result.ok, true);
  assert.equal(seen.url?.endsWith("/upload-buckets"), true);
  assert.equal(seen.method, "POST");
  assert.equal(seen.headers?.get("Authorization"), "Bearer spill_device_v1_preview");
  assert.deepEqual(seen.body, { buckets: [safeBucket] });
});

test("private usage relay viewer uses the authenticated server boundary", async () => {
  const seen: {
    headers?: Headers;
    method?: string;
    url?: string;
  } = {};
  const client = createPrivateUsageRelayClient({
    relayFunctionUrl: "https://otggbleddlmzamgpqxjm.supabase.co/functions/v1/private-usage-relay",
    fetchImpl: async (input, init) => {
      seen.url = String(input);
      seen.method = init?.method;
      seen.headers = new Headers(init?.headers);

      return new Response(
        JSON.stringify({
          user_id: "user_opaque",
          account_id: "account_opaque",
          role: "admin",
          permissions: ["usage.read_own", "device.manage_own", "admin.users.read"]
        }),
        {
          headers: {
            "Content-Type": "application/json"
          },
          status: 200
        }
      );
    }
  });

  const result = await client.getViewer("supabase_user_access_token");

  assert.equal(result.ok, true);
  assert.equal(seen.url?.endsWith("/viewer"), true);
  assert.equal(seen.method, "GET");
  assert.equal(seen.headers?.get("Authorization"), "Bearer supabase_user_access_token");
  if (!result.ok) {
    throw new Error("expected viewer response");
  }
  assert.equal(JSON.stringify(result.data).includes("@"), false);
});
