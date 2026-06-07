export type PrivateUsageRelayEnv = {
  readonly VITE_SUPABASE_URL?: string;
  readonly VITE_SUPABASE_PUBLISHABLE_KEY?: string;
  readonly VITE_SPILL_RELAY_FUNCTION_URL?: string;
};

export type PrivateUsageRelayConfig = {
  status: "configured" | "missing";
  projectRef: string;
  supabaseUrl: string;
  relayFunctionUrl: string;
  hasPublishableKey: boolean;
  missingKeys: string[];
};

export type DeviceGrantRequest = {
  device_key_fingerprint?: string;
};

export type DeviceGrantResponse = {
  grant_code: string;
  expires_in_seconds: number;
};

export type ExchangeDeviceGrantRequest = {
  grant_code: string;
  install_id: string;
  device_key_fingerprint?: string;
};

export type ExchangeDeviceGrantResponse = {
  device_id: string;
  credential: string;
  token_type: "spill_device_v1";
};

export type EncryptedUsageBucketInput = {
  bucket_key: string;
  bucket_kind: "daily";
  bucket_start_at: string;
  bucket_end_at: string;
  timezone: string;
  schema_version: number;
  key_version: number;
  ciphertext: string;
  ciphertext_hash: string;
};

export type UploadBucketsRequest = {
  buckets: EncryptedUsageBucketInput[];
};

export type UploadBucketsResponse = {
  accepted: number;
  uploaded_at: string;
};

export type RemotePrivateUsageDevice = {
  id: string;
  opaque_device_id: string;
  device_key_fingerprint: string | null;
  created_at: string;
  revoked_at: string | null;
  last_upload_at: string | null;
};

export type RemoteEncryptedUsageBucket = {
  id: string;
  device_id: string;
  bucket_key: string;
  bucket_kind: "daily";
  bucket_start_at: string;
  bucket_end_at: string;
  timezone: string;
  schema_version: number;
  key_version: number;
  ciphertext: string;
  ciphertext_hash: string;
  uploaded_at: string;
  updated_at: string;
};

export type ListBucketsResponse = {
  devices: RemotePrivateUsageDevice[];
  buckets: RemoteEncryptedUsageBucket[];
};

export type SpillViewerRole = "admin" | "user";

export type SpillViewerPermission =
  | "usage.read_own"
  | "device.manage_own"
  | "admin.users.read"
  | "admin.user_role.update";

export type SpillViewer = {
  user_id: string;
  account_id: string;
  role: SpillViewerRole;
  permissions: SpillViewerPermission[];
};

export type PrivateUsageRelayResult<T> =
  | {
      ok: true;
      data: T;
    }
  | {
      ok: false;
      status: number;
      error:
        | "network_error"
        | "invalid_response"
        | "relay_rejected"
        | "unsafe_request";
    };

export type PrivateUsageRelayClient = {
  createDeviceGrant: (
    userAccessToken: string,
    request: DeviceGrantRequest
  ) => Promise<PrivateUsageRelayResult<DeviceGrantResponse>>;
  exchangeDeviceGrant: (
    request: ExchangeDeviceGrantRequest
  ) => Promise<PrivateUsageRelayResult<ExchangeDeviceGrantResponse>>;
  uploadBuckets: (
    deviceCredential: string,
    request: UploadBucketsRequest
  ) => Promise<PrivateUsageRelayResult<UploadBucketsResponse>>;
  listBuckets: (
    userAccessToken: string
  ) => Promise<PrivateUsageRelayResult<ListBucketsResponse>>;
  getViewer: (
    userAccessToken: string
  ) => Promise<PrivateUsageRelayResult<SpillViewer>>;
};

export type RelayConnectionDisplayModel = {
  title: string;
  badgeLabel: string;
  badgeTone: "ready" | "warning";
  rows: {
    label: string;
    detail: string;
    value: string;
  }[];
};

type RelayFetch = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;
type JsonObject = Record<string, unknown>;

const SUPABASE_PROJECT_REF = "otggbleddlmzamgpqxjm";
const DEFAULT_SUPABASE_URL = `https://${SUPABASE_PROJECT_REF}.supabase.co`;
const DEFAULT_RELAY_FUNCTION_URL = `${DEFAULT_SUPABASE_URL}/functions/v1/private-usage-relay`;
const LOCALHOST_URL = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?(\/.*)?$/;

const FORBIDDEN_RELAY_FIELD_KEYS = new Set([
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

export function buildPrivateUsageRelayConfig(
  env: PrivateUsageRelayEnv
): PrivateUsageRelayConfig {
  const supabaseUrl = sanitizeServiceUrl(env.VITE_SUPABASE_URL) ?? DEFAULT_SUPABASE_URL;
  const relayFunctionUrl =
    sanitizeServiceUrl(env.VITE_SPILL_RELAY_FUNCTION_URL) ??
    `${supabaseUrl.replace(/\/$/, "")}/functions/v1/private-usage-relay`;
  const hasPublishableKey = Boolean(env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim());
  const missingKeys = hasPublishableKey ? [] : ["VITE_SUPABASE_PUBLISHABLE_KEY"];

  return {
    status: missingKeys.length === 0 ? "configured" : "missing",
    projectRef: projectRefFromSupabaseUrl(supabaseUrl) ?? SUPABASE_PROJECT_REF,
    supabaseUrl,
    relayFunctionUrl,
    hasPublishableKey,
    missingKeys
  };
}

export function findForbiddenRelayPayloadPaths(value: unknown, prefix = ""): string[] {
  if (Array.isArray(value)) {
    return value.flatMap((item, index) =>
      findForbiddenRelayPayloadPaths(item, `${prefix}[${index}]`)
    );
  }

  if (!isRecord(value)) {
    return [];
  }

  return Object.entries(value).flatMap(([key, nested]) => {
    const path = prefix ? `${prefix}.${key}` : key;
    const self = FORBIDDEN_RELAY_FIELD_KEYS.has(key) ? [path] : [];
    return [...self, ...findForbiddenRelayPayloadPaths(nested, path)];
  });
}

export function relayPublishableKeyDisplayLabel(
  config: Pick<PrivateUsageRelayConfig, "hasPublishableKey">
): string {
  return config.hasPublishableKey
    ? "Public browser key present"
    : "Public browser key is not configured";
}

export function buildRelayConnectionDisplayModel(
  config: PrivateUsageRelayConfig
): RelayConnectionDisplayModel {
  const isConfigured = config.status === "configured";

  return {
    title: "Encrypted Cloud Backup",
    badgeLabel: isConfigured ? "Ready" : "Setup needed",
    badgeTone: isConfigured ? "ready" : "warning",
    rows: [
      {
        label: "Backup service",
        detail: "Uploads encrypted daily usage summaries only.",
        value: isConfigured ? "Ready" : "Connection setup incomplete"
      },
      {
        label: "Data boundary",
        detail: "Prompts, responses, commands, paths, and source never sync.",
        value: "Encrypted aggregates"
      }
    ]
  };
}

export function createPrivateUsageRelayClient({
  fetchImpl = fetch,
  relayFunctionUrl
}: {
  fetchImpl?: RelayFetch;
  relayFunctionUrl: string;
}): PrivateUsageRelayClient {
  const baseUrl = relayFunctionUrl.replace(/\/$/, "");

  return {
    createDeviceGrant(userAccessToken, request) {
      return requestJson<DeviceGrantResponse>(
        fetchImpl,
        `${baseUrl}/device-grants`,
        {
          body: request,
          headers: authorizationHeaders(userAccessToken),
          method: "POST"
        }
      );
    },
    exchangeDeviceGrant(request) {
      return requestJson<ExchangeDeviceGrantResponse>(
        fetchImpl,
        `${baseUrl}/exchange-device-grant`,
        {
          body: request,
          method: "POST"
        }
      );
    },
    uploadBuckets(deviceCredential, request) {
      return requestJson<UploadBucketsResponse>(
        fetchImpl,
        `${baseUrl}/upload-buckets`,
        {
          body: request,
          headers: authorizationHeaders(deviceCredential),
          method: "POST"
        }
      );
    },
    listBuckets(userAccessToken) {
      return requestJson<ListBucketsResponse>(
        fetchImpl,
        `${baseUrl}/buckets`,
        {
          headers: authorizationHeaders(userAccessToken),
          method: "GET"
        }
      );
    },
    getViewer(userAccessToken) {
      return requestJson<SpillViewer>(
        fetchImpl,
        `${baseUrl}/viewer`,
        {
          headers: authorizationHeaders(userAccessToken),
          method: "GET"
        }
      );
    }
  };
}

function sanitizeServiceUrl(value: string | undefined): string | null {
  if (!value) {
    return null;
  }

  try {
    const url = new URL(value);
    const normalized = url.toString().replace(/\/$/, "");
    if (url.protocol === "https:" || LOCALHOST_URL.test(normalized)) {
      return normalized;
    }
    return null;
  } catch {
    return null;
  }
}

function projectRefFromSupabaseUrl(value: string): string | null {
  try {
    const host = new URL(value).host;
    return host.endsWith(".supabase.co") ? host.replace(".supabase.co", "") : null;
  } catch {
    return null;
  }
}

function authorizationHeaders(token: string): Record<string, string> {
  return token
    ? {
        Authorization: `Bearer ${token}`
      }
    : {};
}

async function requestJson<T>(
  fetchImpl: RelayFetch,
  url: string,
  options: {
    body?: unknown;
    headers?: Record<string, string>;
    method: "GET" | "POST";
  }
): Promise<PrivateUsageRelayResult<T>> {
  if (options.body && findForbiddenRelayPayloadPaths(options.body).length > 0) {
    return {
      ok: false,
      status: 0,
      error: "unsafe_request"
    };
  }

  try {
    const response = await fetchImpl(url, {
      method: options.method,
      headers: {
        ...options.headers,
        ...(options.body ? { "Content-Type": "application/json" } : {})
      },
      body: options.body ? JSON.stringify(options.body) : undefined
    });

    if (!response.ok) {
      return {
        ok: false,
        status: response.status,
        error: "relay_rejected"
      };
    }

    const data = await response.json();

    if (!isRecord(data)) {
      return {
        ok: false,
        status: response.status,
        error: "invalid_response"
      };
    }

    return {
      ok: true,
      data: data as T
    };
  } catch {
    return {
      ok: false,
      status: 0,
      error: "network_error"
    };
  }
}

function isRecord(value: unknown): value is JsonObject {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}
