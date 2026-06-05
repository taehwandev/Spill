#!/usr/bin/env node

import { appendFile, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { homedir } from "node:os";

const eventKeys = [
  "schema_version",
  "device_id",
  "project_id",
  "artifact_id",
  "run_id",
  "span_id",
  "ai_tool",
  "task_type",
  "stage",
  "model",
  "input_tokens",
  "output_tokens",
  "total_tokens",
  "token_breakdown",
  "latency_ms",
  "created_at",
  "sync_mode",
];

const breakdownKeys = [
  "system",
  "user",
  "history",
  "repo_context",
  "tool_output",
  "generated_output",
  "unknown",
];

const aiTools = new Set([
  "unknown",
  "codex",
  "claude",
  "antigravity",
  "openai",
]);

const forbiddenKeys = new Set([
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
  "secret",
]);

const rawArgs = process.argv.slice(2);
const args = new Set(rawArgs);
const strict = args.has("--strict") || process.env.SPILL_TOKEN_USAGE_HOOK_STRICT === "1";
const dryRun = args.has("--dry-run");
const port = process.env.SPILL_TOKEN_USAGE_PORT || "48731";
const endpoint =
  optionValue("--endpoint") ||
  process.env.SPILL_TOKEN_USAGE_ENDPOINT || `http://127.0.0.1:${port}/v1/usage/events`;
const transport = normalizedTransport(
  optionValue("--transport") ||
    process.env.SPILL_TOKEN_USAGE_TRANSPORT ||
    (optionValue("--endpoint") || process.env.SPILL_TOKEN_USAGE_ENDPOINT ? "http" : "file"),
);
const inboxPath =
  optionValue("--inbox") ||
  process.env.SPILL_TOKEN_USAGE_INBOX_FILE ||
  defaultInboxPath();

const stdin = await readStdin();
if (stdin.trim().length === 0) {
  process.exit(0);
}

let event;
try {
  event = JSON.parse(stdin);
} catch {
  fail("invalid_json", true);
}

try {
  validateEvent(event);
} catch {
  fail("invalid_usage_event", true);
}

if (dryRun) {
  process.stdout.write("OK: safe token usage event\n");
  process.exit(0);
}

try {
  if (transport === "http") {
    await postEvent(endpoint, event);
  } else {
    await appendInboxEvent(inboxPath, event);
  }
} catch {
  fail(transport === "http" ? "bridge_unavailable" : "inbox_unavailable", false);
}

function readStdin() {
  return new Promise((resolve, reject) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => {
      data += chunk;
      if (data.length > 128 * 1024) {
        reject(new Error("stdin_too_large"));
      }
    });
    process.stdin.on("end", () => resolve(data));
    process.stdin.on("error", reject);
  }).catch(() => {
    fail("stdin_read_failed", true);
  });
}

function validateEvent(value) {
  if (!isPlainObject(value)) {
    throw new Error("event_not_object");
  }

  rejectForbiddenKeys(value);
  requireExactKeys(value, eventKeys);

  if (value.schema_version !== 1) {
    throw new Error("schema_version");
  }

  for (const key of ["device_id", "project_id", "artifact_id", "run_id", "span_id"]) {
    if (!/^[A-Za-z0-9_-]{6,64}$/.test(value[key])) {
      throw new Error(key);
    }
  }

  if (!isSafeWorkflowSlug(value.task_type)) {
    throw new Error("task_type");
  }

  if (!aiTools.has(value.ai_tool)) {
    throw new Error("ai_tool");
  }

  if (!isSafeWorkflowSlug(value.stage)) {
    throw new Error("stage");
  }

  if (!/^[A-Za-z0-9_.:-]{2,80}$/.test(value.model)) {
    throw new Error("model");
  }

  for (const key of ["input_tokens", "output_tokens", "total_tokens", "latency_ms"]) {
    if (!isSafeNonNegativeInteger(value[key])) {
      throw new Error(key);
    }
  }

  if (value.total_tokens !== value.input_tokens + value.output_tokens) {
    throw new Error("total_tokens_mismatch");
  }

  if (Number.isNaN(Date.parse(value.created_at))) {
    throw new Error("created_at");
  }

  if (value.sync_mode !== "local_only") {
    throw new Error("sync_mode");
  }

  validateBreakdown(value.token_breakdown, value.total_tokens);
}

function validateBreakdown(value, totalTokens) {
  if (!isPlainObject(value)) {
    throw new Error("breakdown_not_object");
  }

  requireExactKeys(value, breakdownKeys);

  let total = 0;
  for (const key of breakdownKeys) {
    if (!isSafeNonNegativeInteger(value[key])) {
      throw new Error(`token_breakdown.${key}`);
    }
    total += value[key];
  }

  if (total !== totalTokens) {
    throw new Error("token_breakdown_mismatch");
  }
}

function rejectForbiddenKeys(value) {
  if (Array.isArray(value)) {
    for (const item of value) {
      rejectForbiddenKeys(item);
    }
    return;
  }

  if (!isPlainObject(value)) {
    return;
  }

  for (const [key, child] of Object.entries(value)) {
    if (forbiddenKeys.has(key)) {
      throw new Error("forbidden_key");
    }
    rejectForbiddenKeys(child);
  }
}

function requireExactKeys(value, keys) {
  const expected = new Set(keys);
  const actual = Object.keys(value);

  for (const key of actual) {
    if (!expected.has(key)) {
      throw new Error(`unknown_key.${key}`);
    }
  }

  for (const key of keys) {
    if (!Object.hasOwn(value, key)) {
      throw new Error(`missing_key.${key}`);
    }
  }
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isSafeNonNegativeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0;
}

function isSafeWorkflowSlug(value) {
  return typeof value === "string" && /^[a-z][a-z0-9_]{1,40}$/.test(value);
}

async function appendInboxEvent(path, event) {
  await mkdir(dirname(path), { recursive: true, mode: 0o700 });
  await appendFile(path, `${JSON.stringify(event)}\n`, { encoding: "utf8", mode: 0o600 });
}

async function postEvent(url, event) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(event),
  });

  if (!response.ok) {
    fail(`bridge_http_${response.status}`, false);
  }
}

function optionValue(flag) {
  const index = rawArgs.indexOf(flag);
  if (index < 0) return "";
  const value = rawArgs[index + 1];
  return value && !value.startsWith("--") ? value : "";
}

function normalizedTransport(value) {
  const normalized = String(value || "file").toLowerCase();
  if (normalized === "file" || normalized === "http") {
    return normalized;
  }
  fail("invalid_transport", true);
}

function defaultInboxPath() {
  return join(homedir(), "Library", "Application Support", "Spill", "token-metering", "events-inbox.jsonl");
}

function fail(code, invalidInput) {
  if (strict || invalidInput) {
    process.stderr.write(`spill-token-usage-hook: ${code}\n`);
    process.exit(1);
  }

  process.exit(0);
}
