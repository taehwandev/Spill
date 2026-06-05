export type SyncMode = "local_only" | "cloud_aggregate" | "cloud_detailed";

export type TaskType =
  | "uncategorized"
  | "analysis"
  | "prd_drafting"
  | "code_generation"
  | "code_review"
  | "test_generation"
  | "debugging"
  | "documentation"
  | "release_notes";

export type UsageStage =
  | "monitor"
  | "classify"
  | "plan"
  | "draft"
  | "revise"
  | "implement"
  | "verify"
  | "summarize";

export type TokenSource =
  | "system"
  | "user"
  | "history"
  | "repo_context"
  | "tool_output"
  | "generated_output"
  | "unknown";

export type TokenBreakdown = Record<TokenSource, number>;

export type UsageEvent = {
  schema_version: 1;
  device_id: string;
  project_id: string;
  artifact_id: string;
  run_id: string;
  span_id: string;
  task_type: TaskType;
  stage: UsageStage;
  model: string;
  input_tokens: number;
  output_tokens: number;
  total_tokens: number;
  token_breakdown: TokenBreakdown;
  latency_ms: number;
  created_at: string;
  sync_mode: SyncMode;
};

type SafeUsageEventKey = keyof UsageEvent;

const SAFE_USAGE_EVENT_KEYS: ReadonlySet<string> = new Set<SafeUsageEventKey>([
  "schema_version",
  "device_id",
  "project_id",
  "artifact_id",
  "run_id",
  "span_id",
  "task_type",
  "stage",
  "model",
  "input_tokens",
  "output_tokens",
  "total_tokens",
  "token_breakdown",
  "latency_ms",
  "created_at",
  "sync_mode"
]);

export const TASK_TYPES = [
  "uncategorized",
  "analysis",
  "prd_drafting",
  "code_generation",
  "code_review",
  "test_generation",
  "debugging",
  "documentation",
  "release_notes"
] as const satisfies readonly TaskType[];

export const USAGE_STAGES = [
  "monitor",
  "classify",
  "plan",
  "draft",
  "revise",
  "implement",
  "verify",
  "summarize"
] as const satisfies readonly UsageStage[];

export const TOKEN_SOURCES = [
  "system",
  "user",
  "history",
  "repo_context",
  "tool_output",
  "generated_output",
  "unknown"
] as const satisfies readonly TokenSource[];

export const SYNC_MODES = [
  "local_only",
  "cloud_aggregate",
  "cloud_detailed"
] as const satisfies readonly SyncMode[];

export const FORBIDDEN_SYNC_FIELD_KEYS = [
  "command",
  "prompt",
  "response",
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
  "secret"
] as const;

export const FORBIDDEN_SYNC_FIELD_LABELS = [
  "command",
  "prompt",
  "response",
  "file path",
  "repo name",
  "branch name",
  "commit message",
  "terminal output",
  "log body",
  "diff",
  "source content",
  "environment value",
  "secret",
  "arbitrary extra fields"
] as const;

export type SanitizedUsageEventResult =
  | {
      ok: true;
      event: UsageEvent;
      omittedKeys: string[];
    }
  | {
      ok: false;
      reason:
        | "not_an_object"
        | "forbidden_field_present"
        | "invalid_required_field";
      rejectedKeys: string[];
      omittedKeys: string[];
    };

type UnknownRecord = Record<string, unknown>;

export function sanitizeUsageEvent(raw: unknown): SanitizedUsageEventResult {
  if (!isRecord(raw)) {
    return {
      ok: false,
      reason: "not_an_object",
      rejectedKeys: [],
      omittedKeys: []
    };
  }

  const keys = Object.keys(raw);
  const rejectedKeys = findForbiddenKeys(raw);
  const omittedKeys = keys.filter((key) => !SAFE_USAGE_EVENT_KEYS.has(key));

  if (rejectedKeys.length > 0) {
    return {
      ok: false,
      reason: "forbidden_field_present",
      rejectedKeys,
      omittedKeys
    };
  }

  const schemaVersion = raw.schema_version === 1 ? 1 : null;
  const deviceId = sanitizeOpaqueId(raw.device_id);
  const projectId = sanitizeOpaqueId(raw.project_id);
  const artifactId = sanitizeOpaqueId(raw.artifact_id);
  const runId = sanitizeOpaqueId(raw.run_id);
  const spanId = sanitizeOpaqueId(raw.span_id);
  const taskType = pickEnum(raw.task_type, TASK_TYPES);
  const stage = pickEnum(raw.stage, USAGE_STAGES);
  const model = sanitizeModelId(raw.model);
  const inputTokens = sanitizeNonNegativeInteger(raw.input_tokens);
  const outputTokens = sanitizeNonNegativeInteger(raw.output_tokens);
  const totalTokens = sanitizeNonNegativeInteger(raw.total_tokens);
  const tokenBreakdown = sanitizeTokenBreakdown(raw.token_breakdown);
  const latencyMs = sanitizeNonNegativeInteger(raw.latency_ms);
  const createdAt = sanitizeIsoTimestamp(raw.created_at);
  const syncMode = pickEnum(raw.sync_mode, SYNC_MODES);

  if (
    schemaVersion === null ||
    deviceId === null ||
    projectId === null ||
    artifactId === null ||
    runId === null ||
    spanId === null ||
    taskType === null ||
    stage === null ||
    model === null ||
    inputTokens === null ||
    outputTokens === null ||
    totalTokens === null ||
    tokenBreakdown === null ||
    latencyMs === null ||
    createdAt === null ||
    syncMode === null
  ) {
    return {
      ok: false,
      reason: "invalid_required_field",
      rejectedKeys: [],
      omittedKeys
    };
  }

  // Construct a fresh object so unknown or forbidden raw fields cannot be emitted.
  return {
    ok: true,
    event: {
      schema_version: schemaVersion,
      device_id: deviceId,
      project_id: projectId,
      artifact_id: artifactId,
      run_id: runId,
      span_id: spanId,
      task_type: taskType,
      stage,
      model,
      input_tokens: inputTokens,
      output_tokens: outputTokens,
      total_tokens: totalTokens,
      token_breakdown: tokenBreakdown,
      latency_ms: latencyMs,
      created_at: createdAt,
      sync_mode: syncMode
    },
    omittedKeys
  };
}

export function sanitizeUsageEvents(rawEvents: readonly unknown[]): UsageEvent[] {
  return rawEvents
    .map((rawEvent) => sanitizeUsageEvent(rawEvent))
    .filter((result): result is Extract<SanitizedUsageEventResult, { ok: true }> =>
      Boolean(result.ok)
    )
    .map((result) => result.event);
}

export function hasOnlySyncSafeKeys(event: UsageEvent): boolean {
  return Object.keys(event).every((key) => SAFE_USAGE_EVENT_KEYS.has(key));
}

function isRecord(value: unknown): value is UnknownRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function findForbiddenKeys(value: unknown, prefix = ""): string[] {
  if (!isRecord(value)) {
    return [];
  }

  return Object.entries(value).flatMap(([key, childValue]) => {
    const path = prefix ? `${prefix}.${key}` : key;
    const current = FORBIDDEN_SYNC_FIELD_KEYS.includes(
      key as (typeof FORBIDDEN_SYNC_FIELD_KEYS)[number]
    )
      ? [path]
      : [];

    if (isRecord(childValue)) {
      return [...current, ...findForbiddenKeys(childValue, path)];
    }

    return current;
  });
}

function sanitizeOpaqueId(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return /^[A-Za-z0-9_-]{6,64}$/.test(trimmed) ? trimmed : null;
}

function sanitizeModelId(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return /^[A-Za-z0-9_.:-]{2,80}$/.test(trimmed) ? trimmed : null;
}

function sanitizeNonNegativeInteger(value: unknown): number | null {
  return typeof value === "number" &&
    Number.isInteger(value) &&
    Number.isFinite(value) &&
    value >= 0
    ? value
    : null;
}

function sanitizeIsoTimestamp(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const time = Date.parse(value);
  if (!Number.isFinite(time)) {
    return null;
  }

  return new Date(time).toISOString();
}

function sanitizeTokenBreakdown(value: unknown): TokenBreakdown | null {
  if (!isRecord(value)) {
    return null;
  }

  const result = {} as TokenBreakdown;
  for (const source of TOKEN_SOURCES) {
    const count = sanitizeNonNegativeInteger(value[source]);
    if (count === null) {
      return null;
    }
    result[source] = count;
  }

  return result;
}

function pickEnum<T extends string>(
  value: unknown,
  allowedValues: readonly T[]
): T | null {
  return typeof value === "string" && allowedValues.includes(value as T)
    ? (value as T)
    : null;
}
