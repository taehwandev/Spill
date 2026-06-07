import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type JsonObject = Record<string, unknown>;
type ViewerRole = "admin" | "user";

const MAX_BUCKETS_PER_REQUEST = 31;
const DEVICE_TOKEN_PREFIX = "spill_device_v1_";
const TOKEN_TTL_SECONDS = 10 * 60;
const SAFE_OPAQUE_ID = /^[A-Za-z0-9._:-]{1,160}$/;
const SAFE_REQUEST_ID = /^[A-Za-z0-9._:-]{1,160}$/;
const SHA256_HEX = /^[a-f0-9]{64}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const USER_PERMISSIONS = ["usage.read_own", "device.manage_own"] as const;
const ADMIN_PERMISSIONS = [
  ...USER_PERMISSIONS,
  "admin.users.read",
  "admin.user_role.update"
] as const;
const FORBIDDEN_REQUEST_KEYS = new Set([
  "prompt",
  "response",
  "command",
  "file_path",
  "filePath",
  "path",
  "repo_name",
  "repoName",
  "repository",
  "branch_name",
  "branchName",
  "commit_message",
  "commitMessage",
  "terminal_output",
  "terminalOutput",
  "log_body",
  "logBody",
  "diff",
  "source_content",
  "sourceContent",
  "environment_value",
  "environmentValue",
  "secret",
  "input_tokens",
  "output_tokens",
  "total_tokens",
  "token_breakdown",
  "model_breakdown",
  "tool_breakdown",
  "task_breakdown",
  "stage_breakdown"
]);

function supabaseAdmin() {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !serviceRoleKey) {
    throw new Error("relay_not_configured");
  }

  return createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false
    }
  });
}

function allowedOrigin(request: Request): string {
  const configuredOrigin = Deno.env.get("SPILL_WEB_ORIGIN") ?? "http://localhost:5173";
  const localOrigin = "http://localhost:5173";
  const origin = request.headers.get("origin");

  if (!origin) {
    return configuredOrigin;
  }

  return origin === configuredOrigin || origin === localOrigin ? origin : configuredOrigin;
}

function corsHeaders(request: Request): HeadersInit {
  return {
    "access-control-allow-origin": allowedOrigin(request),
    "access-control-allow-headers": "authorization, content-type",
    "access-control-allow-methods": "GET, POST, OPTIONS",
    "vary": "Origin"
  };
}

function jsonResponse(request: Request, status: number, body: JsonObject): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(request),
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store"
    }
  });
}

function routePath(request: Request): string {
  const pathname = new URL(request.url).pathname;
  const marker = "/private-usage-relay";
  const markerIndex = pathname.indexOf(marker);

  if (markerIndex < 0) {
    return "/";
  }

  return pathname.slice(markerIndex + marker.length) || "/";
}

async function readJson(request: Request): Promise<JsonObject | null> {
  try {
    const raw = await request.json();
    return isRecord(raw) ? raw : null;
  } catch {
    return null;
  }
}

function isRecord(value: unknown): value is JsonObject {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function forbiddenPaths(value: unknown, prefix = ""): string[] {
  if (Array.isArray(value)) {
    return value.flatMap((item, index) => forbiddenPaths(item, `${prefix}[${index}]`));
  }

  if (!isRecord(value)) {
    return [];
  }

  return Object.entries(value).flatMap(([key, nested]) => {
    const path = prefix ? `${prefix}.${key}` : key;
    const self = FORBIDDEN_REQUEST_KEYS.has(key) ? [path] : [];
    return [...self, ...forbiddenPaths(nested, path)];
  });
}

function safeString(value: unknown, pattern = SAFE_OPAQUE_ID): string | null {
  return typeof value === "string" && pattern.test(value) ? value : null;
}

function safeIsoTimestamp(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function safeInt(value: unknown, min: number, max: number): number | null {
  return Number.isInteger(value) && value >= min && value <= max ? value : null;
}

function randomToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function requireUser(request: Request, admin = supabaseAdmin()) {
  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice("Bearer ".length) : "";

  if (!token) {
    return { ok: false as const, status: 401, reason: "auth_required" };
  }

  if (token.startsWith(DEVICE_TOKEN_PREFIX)) {
    return { ok: false as const, status: 403, reason: "forbidden" };
  }

  const { data, error } = await admin.auth.getUser(token);

  if (error || !data.user) {
    return { ok: false as const, status: 401, reason: "auth_required" };
  }

  const { data: account, error: accountError } = await admin
    .from("private_usage_accounts")
    .upsert({ owner_user_id: data.user.id }, { onConflict: "owner_user_id" })
    .select("id, owner_user_id")
    .single();

  if (accountError || !account) {
    return { ok: false as const, status: 500, reason: "account_unavailable" };
  }

  const role = await ensureViewerMembership(admin, account.id, data.user, request);

  return { ok: true as const, user: data.user, account, role };
}

async function requireAdmin(request: Request, admin = supabaseAdmin()) {
  const user = await requireUser(request, admin);

  if (!user.ok) {
    return user;
  }

  if (user.role !== "admin") {
    await writeAdminAudit(admin, {
      accountId: user.account.id,
      actorUserId: user.user.id,
      action: "admin.access",
      result: "denied",
      reasonCode: "role_denied",
      requestId: requestId(request)
    });
    return { ok: false as const, status: 403, reason: "forbidden" };
  }

  return user;
}

function normalizeEmail(value: unknown): string | null {
  return typeof value === "string" && value.includes("@")
    ? value.trim().toLowerCase()
    : null;
}

function adminEmail(): string | null {
  return normalizeEmail(Deno.env.get("SPILL_ADMIN_EMAIL"));
}

function desiredRoleForUser(user: { email?: string }): ViewerRole | null {
  const configuredAdminEmail = adminEmail();
  if (!configuredAdminEmail) {
    return null;
  }

  return normalizeEmail(user.email) === configuredAdminEmail ? "admin" : "user";
}

function permissionsForRole(role: ViewerRole): readonly string[] {
  return role === "admin" ? ADMIN_PERMISSIONS : USER_PERMISSIONS;
}

async function ensureViewerMembership(
  admin: ReturnType<typeof supabaseAdmin>,
  accountId: string,
  user: { id: string; email?: string },
  request: Request
): Promise<ViewerRole> {
  const { data: existing } = await admin
    .from("private_usage_account_memberships")
    .select("id, role")
    .eq("account_id", accountId)
    .eq("user_id", user.id)
    .maybeSingle();

  const configuredRole = desiredRoleForUser(user);
  const role = configuredRole ?? (existing?.role === "admin" ? "admin" : "user");

  if (existing?.role === role) {
    return role;
  }

  const { error } = await admin
    .from("private_usage_account_memberships")
    .upsert({
      account_id: accountId,
      user_id: user.id,
      role
    }, { onConflict: "account_id,user_id" });

  if (!error) {
    await writeAdminAudit(admin, {
      accountId,
      actorUserId: user.id,
      targetUserId: user.id,
      action: role === "admin" ? "membership.bootstrap_admin" : "membership.ensure_user",
      result: existing ? "updated" : "created",
      reasonCode: role === "admin" ? "admin_secret_match" : "default_user",
      requestId: requestId(request)
    });
  }

  return role;
}

function requestId(request: Request): string {
  const existing = safeString(request.headers.get("x-request-id"), SAFE_REQUEST_ID);
  return existing ?? crypto.randomUUID();
}

async function writeAdminAudit(
  admin: ReturnType<typeof supabaseAdmin>,
  event: {
    accountId: string;
    actorUserId?: string;
    targetUserId?: string;
    action: string;
    result: "created" | "updated" | "denied" | "failed";
    reasonCode?: string;
    requestId?: string;
  }
) {
  await admin.from("private_usage_admin_audit_logs").insert({
    account_id: event.accountId,
    actor_user_id: event.actorUserId ?? null,
    target_user_id: event.targetUserId ?? null,
    action: event.action,
    result: event.result,
    reason_code: event.reasonCode ?? null,
    request_id: event.requestId ?? null
  });
}

async function requireDeviceCredential(request: Request, admin = supabaseAdmin()) {
  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.startsWith(`Bearer ${DEVICE_TOKEN_PREFIX}`)
    ? authorization.slice("Bearer ".length)
    : "";

  if (!token) {
    return { ok: false as const, status: 401, reason: "device_auth_required" };
  }

  const credentialHash = await sha256Hex(token);
  const { data, error } = await admin
    .from("private_usage_device_credentials")
    .select("id, account_id, device_id, expires_at, revoked_at")
    .eq("credential_hash", credentialHash)
    .maybeSingle();

  if (error || !data || data.revoked_at) {
    return { ok: false as const, status: 403, reason: "device_forbidden" };
  }

  if (data.expires_at && new Date(data.expires_at).getTime() <= Date.now()) {
    return { ok: false as const, status: 403, reason: "device_forbidden" };
  }

  await admin
    .from("private_usage_device_credentials")
    .update({ last_used_at: new Date().toISOString() })
    .eq("id", data.id);

  return { ok: true as const, credential: data };
}

async function handleCreateDeviceGrant(request: Request): Promise<Response> {
  const admin = supabaseAdmin();
  const user = await requireUser(request, admin);

  if (!user.ok) {
    return jsonResponse(request, user.status, { error: user.reason });
  }

  const body = await readJson(request);
  if (!body || forbiddenPaths(body).length > 0) {
    return jsonResponse(request, 400, { error: "invalid_request" });
  }

  const deviceKeyFingerprint = body.device_key_fingerprint === undefined
    ? null
    : safeString(body.device_key_fingerprint);

  if (body.device_key_fingerprint !== undefined && !deviceKeyFingerprint) {
    return jsonResponse(request, 400, { error: "invalid_request" });
  }

  const grantCode = randomToken();
  const grantHash = await sha256Hex(grantCode);
  const expiresAt = new Date(Date.now() + TOKEN_TTL_SECONDS * 1000).toISOString();

  const { error } = await admin.from("private_usage_device_grants").insert({
    account_id: user.account.id,
    grant_hash: grantHash,
    device_key_fingerprint: deviceKeyFingerprint,
    expires_at: expiresAt
  });

  if (error) {
    return jsonResponse(request, 500, { error: "grant_unavailable" });
  }

  return jsonResponse(request, 201, {
    grant_code: grantCode,
    expires_in_seconds: TOKEN_TTL_SECONDS
  });
}

async function handleViewer(request: Request): Promise<Response> {
  const admin = supabaseAdmin();
  const user = await requireUser(request, admin);

  if (!user.ok) {
    return jsonResponse(request, user.status, { error: user.reason });
  }

  return jsonResponse(request, 200, {
    user_id: user.user.id,
    account_id: user.account.id,
    role: user.role,
    permissions: permissionsForRole(user.role)
  });
}

async function listDevicesForUser(
  admin: ReturnType<typeof supabaseAdmin>,
  accountId: string
) {
  return await admin
    .from("private_usage_devices")
    .select("id, opaque_device_id, device_key_fingerprint, created_at, revoked_at, last_upload_at")
    .eq("account_id", accountId)
    .order("created_at", { ascending: true });
}

async function handleListDevices(request: Request): Promise<Response> {
  const admin = supabaseAdmin();
  const user = await requireUser(request, admin);

  if (!user.ok) {
    return jsonResponse(request, user.status, { error: user.reason });
  }

  const { data, error } = await listDevicesForUser(admin, user.account.id);

  if (error) {
    return jsonResponse(request, 500, { error: "devices_unavailable" });
  }

  return jsonResponse(request, 200, {
    devices: data ?? []
  });
}

async function handleRevokeDevice(request: Request): Promise<Response> {
  const admin = supabaseAdmin();
  const user = await requireUser(request, admin);

  if (!user.ok) {
    return jsonResponse(request, user.status, { error: user.reason });
  }

  const body = await readJson(request);
  if (!body || forbiddenPaths(body).length > 0) {
    return jsonResponse(request, 400, { error: "invalid_request" });
  }

  const deviceId = safeString(body.device_id, UUID);
  if (!deviceId) {
    return jsonResponse(request, 400, { error: "invalid_request" });
  }

  const revokedAt = new Date().toISOString();
  const { data: device, error: deviceError } = await admin
    .from("private_usage_devices")
    .update({ revoked_at: revokedAt })
    .eq("account_id", user.account.id)
    .eq("id", deviceId)
    .select("id")
    .maybeSingle();

  if (deviceError) {
    await writeAdminAudit(admin, {
      accountId: user.account.id,
      actorUserId: user.user.id,
      targetUserId: user.user.id,
      action: "device.revoke",
      result: "failed",
      reasonCode: "device_update_failed",
      requestId: requestId(request)
    });
    return jsonResponse(request, 500, { error: "device_unavailable" });
  }

  if (!device) {
    await writeAdminAudit(admin, {
      accountId: user.account.id,
      actorUserId: user.user.id,
      action: "device.revoke",
      result: "denied",
      reasonCode: "device_not_found",
      requestId: requestId(request)
    });
    return jsonResponse(request, 404, { error: "device_not_found" });
  }

  const { error: credentialError } = await admin
    .from("private_usage_device_credentials")
    .update({ revoked_at: revokedAt })
    .eq("account_id", user.account.id)
    .eq("device_id", deviceId)
    .is("revoked_at", null);

  if (credentialError) {
    await writeAdminAudit(admin, {
      accountId: user.account.id,
      actorUserId: user.user.id,
      targetUserId: user.user.id,
      action: "device.revoke",
      result: "failed",
      reasonCode: "credential_update_failed",
      requestId: requestId(request)
    });
    return jsonResponse(request, 500, { error: "device_unavailable" });
  }

  await writeAdminAudit(admin, {
    accountId: user.account.id,
    actorUserId: user.user.id,
    targetUserId: user.user.id,
    action: "device.revoke",
    result: "updated",
    reasonCode: "user_requested",
    requestId: requestId(request)
  });

  return jsonResponse(request, 200, {
    device_id: deviceId,
    revoked_at: revokedAt
  });
}

async function handleAdminRoute(request: Request): Promise<Response> {
  const admin = supabaseAdmin();
  const user = await requireAdmin(request, admin);

  if (!user.ok) {
    return jsonResponse(request, user.status, { error: user.reason });
  }

  return jsonResponse(request, 501, { error: "admin_route_not_ready" });
}

async function handleExchangeDeviceGrant(request: Request): Promise<Response> {
  const admin = supabaseAdmin();
  const body = await readJson(request);

  if (!body || forbiddenPaths(body).length > 0) {
    return jsonResponse(request, 400, { error: "invalid_request" });
  }

  const grantCode = typeof body.grant_code === "string" ? body.grant_code : "";
  const installId = safeString(body.install_id);
  const deviceKeyFingerprint = body.device_key_fingerprint === undefined
    ? null
    : safeString(body.device_key_fingerprint);

  if (!grantCode || !installId || (body.device_key_fingerprint !== undefined && !deviceKeyFingerprint)) {
    return jsonResponse(request, 400, { error: "invalid_request" });
  }

  const grantHash = await sha256Hex(grantCode);
  const { data: grant, error: grantError } = await admin
    .from("private_usage_device_grants")
    .select("id, account_id")
    .eq("grant_hash", grantHash)
    .gt("expires_at", new Date().toISOString())
    .is("consumed_at", null)
    .maybeSingle();

  if (grantError || !grant) {
    return jsonResponse(request, 403, { error: "grant_forbidden" });
  }

  const { data: device, error: deviceError } = await admin
    .from("private_usage_devices")
    .upsert({
      account_id: grant.account_id,
      opaque_device_id: installId,
      device_key_fingerprint: deviceKeyFingerprint,
      revoked_at: null
    }, { onConflict: "account_id,opaque_device_id" })
    .select("id")
    .single();

  if (deviceError || !device) {
    return jsonResponse(request, 500, { error: "device_unavailable" });
  }

  const credential = `${DEVICE_TOKEN_PREFIX}${randomToken()}`;
  const credentialHash = await sha256Hex(credential);
  const { error: credentialError } = await admin.from("private_usage_device_credentials").insert({
    account_id: grant.account_id,
    device_id: device.id,
    credential_hash: credentialHash
  });

  if (credentialError) {
    return jsonResponse(request, 500, { error: "credential_unavailable" });
  }

  await admin
    .from("private_usage_device_grants")
    .update({ consumed_at: new Date().toISOString() })
    .eq("id", grant.id);

  return jsonResponse(request, 200, {
    device_id: device.id,
    credential,
    token_type: "spill_device_v1"
  });
}

function sanitizeBucket(raw: unknown): JsonObject | null {
  if (!isRecord(raw) || forbiddenPaths(raw).length > 0) {
    return null;
  }

  const bucketKey = typeof raw.bucket_key === "string" && raw.bucket_key.length <= 128
    ? raw.bucket_key
    : null;
  const bucketKind = raw.bucket_kind === "daily" ? "daily" : null;
  const bucketStartAt = safeIsoTimestamp(raw.bucket_start_at);
  const bucketEndAt = safeIsoTimestamp(raw.bucket_end_at);
  const timezone = typeof raw.timezone === "string" && raw.timezone.length >= 1 && raw.timezone.length <= 80
    ? raw.timezone
    : null;
  const schemaVersion = safeInt(raw.schema_version, 1, 99);
  const keyVersion = safeInt(raw.key_version, 1, 99);
  const ciphertext = typeof raw.ciphertext === "string" && raw.ciphertext.length >= 1 && raw.ciphertext.length <= 262144
    ? raw.ciphertext
    : null;
  const ciphertextHash = safeString(raw.ciphertext_hash, SHA256_HEX);

  if (
    !bucketKey ||
    !bucketKind ||
    !bucketStartAt ||
    !bucketEndAt ||
    !timezone ||
    schemaVersion === null ||
    keyVersion === null ||
    !ciphertext ||
    !ciphertextHash ||
    new Date(bucketEndAt).getTime() <= new Date(bucketStartAt).getTime()
  ) {
    return null;
  }

  return {
    bucket_key: bucketKey,
    bucket_kind: bucketKind,
    bucket_start_at: bucketStartAt,
    bucket_end_at: bucketEndAt,
    timezone,
    schema_version: schemaVersion,
    key_version: keyVersion,
    ciphertext,
    ciphertext_hash: ciphertextHash
  };
}

async function handleUploadBuckets(request: Request): Promise<Response> {
  const admin = supabaseAdmin();
  const device = await requireDeviceCredential(request, admin);

  if (!device.ok) {
    return jsonResponse(request, device.status, { error: device.reason });
  }

  const body = await readJson(request);
  if (!body || forbiddenPaths(body).length > 0 || !Array.isArray(body.buckets)) {
    return jsonResponse(request, 400, { error: "invalid_request" });
  }

  if (body.buckets.length < 1 || body.buckets.length > MAX_BUCKETS_PER_REQUEST) {
    return jsonResponse(request, 400, { error: "invalid_bucket_count" });
  }

  const now = new Date().toISOString();
  const rows = body.buckets.map((bucket) => {
    const sanitized = sanitizeBucket(bucket);
    return sanitized
      ? {
          ...sanitized,
          account_id: device.credential.account_id,
          device_id: device.credential.device_id,
          uploaded_at: now,
          updated_at: now
        }
      : null;
  });

  if (rows.some((row) => row === null)) {
    return jsonResponse(request, 400, { error: "invalid_bucket" });
  }

  const { error } = await admin
    .from("private_usage_buckets")
    .upsert(rows, { onConflict: "account_id,device_id,bucket_key,schema_version" });

  if (error) {
    return jsonResponse(request, 500, { error: "upload_unavailable" });
  }

  await admin
    .from("private_usage_devices")
    .update({ last_upload_at: now })
    .eq("id", device.credential.device_id);

  return jsonResponse(request, 200, {
    accepted: rows.length,
    uploaded_at: now
  });
}

async function handleListBuckets(request: Request): Promise<Response> {
  const admin = supabaseAdmin();
  const user = await requireUser(request, admin);

  if (!user.ok) {
    return jsonResponse(request, user.status, { error: user.reason });
  }

  const { data: devices, error: devicesError } = await listDevicesForUser(admin, user.account.id);

  if (devicesError) {
    return jsonResponse(request, 500, { error: "devices_unavailable" });
  }

  const { data: buckets, error: bucketsError } = await admin
    .from("private_usage_buckets")
    .select("id, device_id, bucket_key, bucket_kind, bucket_start_at, bucket_end_at, timezone, schema_version, key_version, ciphertext, ciphertext_hash, uploaded_at, updated_at")
    .eq("account_id", user.account.id)
    .order("bucket_start_at", { ascending: false });

  if (bucketsError) {
    return jsonResponse(request, 500, { error: "buckets_unavailable" });
  }

  return jsonResponse(request, 200, {
    devices: devices ?? [],
    buckets: buckets ?? []
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(request) });
  }

  try {
    const path = routePath(request);

    if (request.method === "POST" && path === "/device-grants") {
      return await handleCreateDeviceGrant(request);
    }

    if (request.method === "POST" && path === "/exchange-device-grant") {
      return await handleExchangeDeviceGrant(request);
    }

    if (request.method === "POST" && path === "/upload-buckets") {
      return await handleUploadBuckets(request);
    }

    if (request.method === "GET" && path === "/buckets") {
      return await handleListBuckets(request);
    }

    if (request.method === "GET" && path === "/devices") {
      return await handleListDevices(request);
    }

    if (request.method === "POST" && path === "/devices/revoke") {
      return await handleRevokeDevice(request);
    }

    if (request.method === "GET" && path === "/viewer") {
      return await handleViewer(request);
    }

    if (path.startsWith("/admin/")) {
      return await handleAdminRoute(request);
    }

    return jsonResponse(request, 404, { error: "not_found" });
  } catch {
    return jsonResponse(request, 500, { error: "relay_unavailable" });
  }
});
