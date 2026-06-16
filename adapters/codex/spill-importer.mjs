#!/usr/bin/env node

import { createHash, randomUUID } from "node:crypto";
import { createReadStream } from "node:fs";
import { mkdir, readdir, readFile, rename, stat, unlink, writeFile } from "node:fs/promises";
import { createInterface } from "node:readline";
import { dirname, join } from "node:path";
import { homedir } from "node:os";

const DEFAULT_PORT = "48731";
const DEFAULT_SINCE_HOURS = 24;
const DEFAULT_WATCH_INTERVAL_MS = 5000;
const MAX_LINE_BYTES = 1024 * 1024;
const WRITE_TOOL_NAMES = new Set([
  "apply_patch",
  "edit",
  "write",
  "multi_edit",
  "multiedit",
  "notebook_edit",
  "notebookedit",
]);
const READ_TOOL_NAMES = new Set([
  "cat",
  "find",
  "grep",
  "ls",
  "nl",
  "open",
  "read",
  "rg",
  "screenshot",
  "sed",
  "view_image",
  "wc",
  "web_fetch",
  "web_search",
  "webfetch",
  "websearch",
]);
const SHELL_TOOL_NAMES = new Set([
  "bash",
  "exec",
  "exec_command",
  "functions.exec_command",
  "run_command",
  "shell",
  "terminal",
]);

const options = parseArgs(process.argv.slice(2));
const codexHome = options.codexHome ?? process.env.CODEX_HOME ?? join(homedir(), ".codex");
const port = process.env.SPILL_TOKEN_USAGE_PORT || DEFAULT_PORT;
const endpoint =
  options.endpoint ??
  process.env.SPILL_TOKEN_USAGE_ENDPOINT ??
  `http://127.0.0.1:${port}/v1/usage/events`;
const transport = normalizedTransport(
  options.transport ??
    process.env.SPILL_TOKEN_USAGE_TRANSPORT ??
    (options.endpoint || process.env.SPILL_TOKEN_USAGE_ENDPOINT ? "http" : "file"),
);
const inboxPath =
  options.inboxPath ??
  process.env.SPILL_TOKEN_USAGE_INBOX_DIR ??
  join(
    homedir(),
    "Library",
    "Application Support",
    "Spill",
    "token-metering",
    "events-inbox",
  );
const eventsPath =
  options.eventsPath ??
  process.env.SPILL_TOKEN_USAGE_EVENTS_FILE ??
  join(
    homedir(),
    "Library",
    "Application Support",
    "Spill",
    "token-metering",
    "events.json",
  );
const statePath =
  options.statePath ??
  process.env.SPILL_CODEX_IMPORT_STATE ??
  join(
    homedir(),
    "Library",
    "Application Support",
    "Spill",
    "token-metering",
    "codex-session-import-state.json",
  );
const labelPath =
  options.labelPath ??
  process.env.SPILL_TOKEN_USAGE_LABEL_FILE ??
  join(
    homedir(),
    "Library",
    "Application Support",
    "Spill",
    "token-metering",
    "label-context",
    "codex.json",
  );
const runtimeLabel = await readRuntimeLabel(labelPath, "codex");

const strict = options.strict || process.env.SPILL_TOKEN_USAGE_IMPORT_STRICT === "1";
const dryRun = options.dryRun;
const markExisting = options.markExisting;
const watch = options.watch;
const intervalMS = options.intervalMS ?? DEFAULT_WATCH_INTERVAL_MS;
const taskTypeOverride = safeWorkflowSlug(
  options.taskType ??
    process.env.SPILL_TOKEN_USAGE_TASK_TYPE ??
    process.env.SPILL_WORKFLOW_TASK_TYPE,
);
const stageOverride = safeWorkflowSlug(
  options.stage ??
    process.env.SPILL_TOKEN_USAGE_STAGE ??
    process.env.SPILL_WORKFLOW_STAGE,
);
const afterDate = options.after ? new Date(options.after) : sinceDate(options.sinceHours ?? DEFAULT_SINCE_HOURS);

if (Number.isNaN(afterDate.getTime())) {
  fail("invalid_after", true);
}

if (watch) {
  while (true) {
    await importOnce().catch((error) => {
      if (strict) {
        throw error;
      }
    });
    await sleep(intervalMS);
  }
} else {
  await importOnce();
}

async function importOnce() {
  const state = await readState(statePath);
  const storedSpans = dryRun
    ? new Set()
    : transport === "http"
      ? await readBridgeSpanIDs(endpoint)
      : await readLocalSpanIDs(eventsPath, inboxPath);
  const sources = await discoverCodexSessionFiles(codexHome, afterDate);
  let scannedFiles = 0;
  let importedEvents = 0;
  let markedExisting = 0;
  let skippedSeen = 0;
  let usedRuntimeLabel = false;

  for (const source of sources) {
    scannedFiles += 1;
    const records = await parseSessionFile(source, afterDate, state);
    for (const record of records) {
      const event = record.event;
      if (state.sentSpanIDs.includes(event.span_id) || storedSpans.has(event.span_id)) {
        skippedSeen += 1;
        continue;
      }

      if (markExisting) {
        markedExisting += 1;
      } else if (dryRun) {
        importedEvents += 1;
      } else {
        if (transport === "http") {
          await postEvent(endpoint, event);
        } else {
          await appendInboxEvent(inboxPath, event);
        }
        importedEvents += 1;
        storedSpans.add(event.span_id);
      }

      if (record.usedRuntimeLabel) {
        usedRuntimeLabel = true;
      }
      state.sentSpanIDs.push(event.span_id);
      if (state.sentSpanIDs.length > 5000) {
        state.sentSpanIDs = state.sentSpanIDs.slice(-5000);
      }
    }
  }

  state.updatedAt = new Date().toISOString();
  if (!dryRun) {
    await writeState(statePath, state);
    if (usedRuntimeLabel) {
      await unlink(labelPath).catch(() => {});
    }
  }

  if (options.json) {
    process.stdout.write(`${JSON.stringify({
      scanned_files: scannedFiles,
      imported_events: importedEvents,
      marked_existing: markedExisting,
      skipped_seen: skippedSeen,
      codex_home: codexHome,
      endpoint,
      transport,
      inbox_path: transport === "file" ? inboxPath : undefined,
      dry_run: dryRun,
    })}\n`);
  }
}

async function discoverCodexSessionFiles(root, after) {
  const sessionsDir = join(root, "sessions");
  const files = [];
  const years = await safeReadDir(sessionsDir);
  for (const year of years) {
    if (!/^\d{4}$/.test(year)) continue;
    const yearDir = join(sessionsDir, year);
    for (const month of await safeReadDir(yearDir)) {
      if (!/^\d{2}$/.test(month)) continue;
      const monthDir = join(yearDir, month);
      for (const day of await safeReadDir(monthDir)) {
        if (!/^\d{2}$/.test(day)) continue;
        const dayDir = join(monthDir, day);
        for (const file of await safeReadDir(dayDir)) {
          if (!file.startsWith("rollout-") || !file.endsWith(".jsonl")) continue;
          const path = join(dayDir, file);
          const info = await stat(path).catch(() => null);
          if (!info?.isFile()) continue;
          if (info.mtime < after) continue;
          files.push(path);
        }
      }
    }
  }
  return files.sort();
}

async function parseSessionFile(path, after, state) {
  const counters = {
    sessionID: "",
    sessionModel: "",
    toolNames: new Set(),
    previousCumulativeTotal: null,
    previousInput: 0,
    previousCached: 0,
    previousOutput: 0,
    previousReasoning: 0,
    eventIndex: 0,
  };
  let latest = null;

  const stream = createReadStream(path, { encoding: "utf8" });
  stream.on("error", () => {});
  const lines = createInterface({ input: stream, crlfDelay: Infinity });

  try {
    for await (const line of lines) {
      if (!line || line.length > MAX_LINE_BYTES) continue;
      if (line.includes('"type":"session_meta"') || line.includes('"type": "session_meta"')) {
        captureSessionMeta(line, counters);
        continue;
      }
      if (line.includes('"type":"turn_context"') || line.includes('"type": "turn_context"')) {
        const model = rawJSONField(line, "model");
        if (model) counters.sessionModel = model;
        continue;
      }
      if (mayContainToolMetadata(line)) {
        collectSafeToolNames(safeJSON(line), counters.toolNames);
      }
      if (!line.includes('"token_count"')) continue;

      const parsed = safeJSON(line);
      if (!parsed || parsed.type !== "event_msg" || parsed.payload?.type !== "token_count") {
        continue;
      }

      const timestamp = parsed.timestamp ? new Date(parsed.timestamp) : new Date();
      if (Number.isNaN(timestamp.getTime()) || timestamp < after) continue;

      const usage = usageRecordFromTokenCount(parsed.payload.info);
      if (!usage) continue;

      latest = { timestamp, usage };
    }
  } finally {
    lines.close();
    stream.destroy();
  }

  if (!latest) return [];

  const sessionKey = counters.sessionID || path;
  const cursorKey = opaqueHash(sessionKey);
  const cursor = state.sessionCursors[cursorKey];
  const delta = usageDelta(latest.usage, cursor);
  const nextCursor = cursorFromUsage(latest.usage);
  if (nextCursor) {
    state.sessionCursors[cursorKey] = nextCursor;
  }
  if (!delta) return [];

  counters.eventIndex += 1;
  const fallbackLabel = fallbackLabelFromTools(counters.toolNames);
  const eventLabel = labelForTimestamp(runtimeLabel, latest.timestamp);
  const usedRuntimeLabel = Boolean(
    (!taskTypeOverride && eventLabel.taskType) ||
      (!stageOverride && eventLabel.stage),
  );
  return [
    {
      event: toSpillEvent({
        sourcePath: path,
        sessionID: counters.sessionID,
        eventIndex: counters.eventIndex,
        timestamp: latest.timestamp,
        model: latest.usage.model || counters.sessionModel || "codex-unknown",
        inputTokens: delta.inputTokens,
        outputTokens: delta.outputTokens,
        cumulativeTotal: latest.usage.total.totalTokens,
        projectID: eventLabel.projectID,
        taskType: taskTypeOverride ?? eventLabel.taskType ?? fallbackLabel.taskType,
        stage: stageOverride ?? eventLabel.stage ?? fallbackLabel.stage,
      }),
      usedRuntimeLabel,
    },
  ];
}

function captureSessionMeta(line, counters) {
  if (!rawJSONField(line, "originator")?.toLowerCase().startsWith("codex")) return;
  counters.sessionID = rawJSONField(line, "session_id") || counters.sessionID;
  counters.sessionModel = rawJSONField(line, "model") || counters.sessionModel;
}

function usageRecordFromTokenCount(info) {
  if (!info || typeof info !== "object") return null;

  const total = tokenUsage(info.total_token_usage);
  const last = tokenUsage(info.last_token_usage);
  if (!last.hasAny && !total.hasAny) return null;

  return {
    model: typeof info.model === "string" ? info.model : typeof info.model_name === "string" ? info.model_name : "",
    last,
    total,
  };
}

function usageDelta(record, cursor) {
  let inputTokens = 0;
  let outputTokens = 0;

  if (cursor && record.total.hasAny && record.total.totalTokens >= (cursor.totalTokens ?? 0)) {
    inputTokens = Math.max(0, record.total.inputTokens - cursor.inputTokens);
    outputTokens =
      Math.max(0, record.total.outputTokens - cursor.outputTokens) +
      Math.max(0, record.total.reasoningTokens - cursor.reasoningTokens);
  } else if (record.last.hasAny) {
    inputTokens = record.last.inputTokens;
    outputTokens = record.last.outputTokens + record.last.reasoningTokens;
  } else {
    return null;
  }

  if (inputTokens === 0 && outputTokens === 0) return null;
  return { inputTokens, outputTokens };
}

function cursorFromUsage(record) {
  if (!record.total.hasAny) return null;
  return {
    inputTokens: record.total.inputTokens,
    outputTokens: record.total.outputTokens,
    reasoningTokens: record.total.reasoningTokens,
    totalTokens: record.total.totalTokens,
  };
}

function tokenUsage(value) {
  if (!value || typeof value !== "object") {
    return {
      hasAny: false,
      inputTokens: 0,
      cachedInputTokens: 0,
      outputTokens: 0,
      reasoningTokens: 0,
      totalTokens: 0,
    };
  }

  const inputTokens = safeToken(value.input_tokens);
  const cachedInputTokens = safeToken(value.cached_input_tokens);
  const outputTokens = safeToken(value.output_tokens);
  const reasoningTokens = safeToken(value.reasoning_output_tokens);
  const totalTokens = safeToken(value.total_tokens);

  return {
    hasAny: inputTokens > 0 || cachedInputTokens > 0 || outputTokens > 0 || reasoningTokens > 0 || totalTokens > 0,
    inputTokens,
    cachedInputTokens,
    outputTokens,
    reasoningTokens,
    totalTokens,
  };
}

function mayContainToolMetadata(line) {
  return line.includes('"tool"') || line.includes('"function_call"') || line.includes('"recipient_name"');
}

function collectSafeToolNames(value, names) {
  if (!value || typeof value !== "object") return;
  if (Array.isArray(value)) {
    for (const item of value) {
      collectSafeToolNames(item, names);
    }
    return;
  }

  const type = typeof value.type === "string" ? value.type.toLowerCase() : "";
  if (type === "tool_use" || type === "tool_call" || type === "function_call" || type.includes("tool")) {
    addRecognizedToolName(names, value.name);
    addRecognizedToolName(names, value.tool_name);
    addRecognizedToolName(names, value.toolName);
  }
  addRecognizedToolName(names, value.recipient_name);

  for (const item of Object.values(value)) {
    collectSafeToolNames(item, names);
  }
}

function addRecognizedToolName(names, value) {
  const name = normalizeToolName(value);
  if (!name) return;
  if (WRITE_TOOL_NAMES.has(name) || READ_TOOL_NAMES.has(name) || SHELL_TOOL_NAMES.has(name)) {
    names.add(name);
  }
}

function fallbackLabelFromTools(toolNames) {
  if (hasAny(toolNames, WRITE_TOOL_NAMES)) {
    return { taskType: "code_generation", stage: "implement" };
  }
  if (toolNames.size === 0) {
    return { taskType: "analysis", stage: "summarize" };
  }
  if (allKnownReadOrShell(toolNames)) {
    return {
      taskType: "analysis",
      stage: hasAny(toolNames, SHELL_TOOL_NAMES) ? "verify" : "summarize",
    };
  }
  return { taskType: "uncategorized", stage: "summarize" };
}

function hasAny(values, candidates) {
  for (const value of values) {
    if (candidates.has(value)) return true;
  }
  return false;
}

function allKnownReadOrShell(values) {
  for (const value of values) {
    if (!READ_TOOL_NAMES.has(value) && !SHELL_TOOL_NAMES.has(value)) return false;
  }
  return true;
}

function toSpillEvent({
  sourcePath,
  sessionID,
  eventIndex,
  timestamp,
  model,
  inputTokens,
  outputTokens,
  cumulativeTotal,
  projectID,
  taskType,
  stage,
}) {
  const totalTokens = inputTokens + outputTokens;
  const sessionKey = sessionID || sourcePath;
  const cumulativeKey = cumulativeTotal > 0 ? String(cumulativeTotal) : String(eventIndex);
  const spanHash = opaqueHash(`${sourcePath}:${sessionKey}:${cumulativeKey}:${timestamp.toISOString()}`);
  const runHash = opaqueHash(sessionKey);

  return {
    schema_version: 1,
    device_id: "device_local",
    project_id: optionalOpaqueID(projectID) ?? "project_global",
    artifact_id: "artifact_codex",
    run_id: `run_${runHash}`,
    span_id: `span_${spanHash}`,
    ai_tool: "codex",
    task_type: taskType,
    stage,
    model: safeModel(model),
    input_tokens: inputTokens,
    output_tokens: outputTokens,
    total_tokens: totalTokens,
    token_breakdown: {
      system: 0,
      user: 0,
      history: 0,
      repo_context: 0,
      tool_output: 0,
      generated_output: outputTokens,
      unknown: inputTokens,
    },
    latency_ms: 0,
    created_at: timestamp.toISOString(),
  };
}

async function readBridgeSpanIDs(url) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: { "Connection": "close" },
      });
      if (!response.ok) return new Set();
      const envelope = await response.json();
      const events = Array.isArray(envelope.events) ? envelope.events : [];
      return new Set(events.map((event) => event.span_id).filter((spanID) => typeof spanID === "string"));
    } catch {
      if (attempt < 2) {
        await sleep(100 * (attempt + 1));
        continue;
      }
      if (strict) fail("bridge_unavailable", false);
      return new Set();
    }
  }
  return new Set();
}

async function postEvent(url, event) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Connection": "close",
        },
        body: JSON.stringify(event),
      });
      if (!response.ok) fail(`bridge_http_${response.status}`, false);
      return;
    } catch {
      if (attempt < 2) {
        await sleep(100 * (attempt + 1));
        continue;
      }
      fail("bridge_unavailable", false);
    }
  }
}

async function appendInboxEvent(path, event) {
  await mkdir(path, { recursive: true, mode: 0o700 });
  const id = randomUUID();
  const temporaryPath = join(path, `.${id}.tmp`);
  const finalPath = join(path, `${id}.json`);
  await writeFile(temporaryPath, JSON.stringify(event), {
    encoding: "utf8",
    mode: 0o600,
    flag: "wx",
  });
  await rename(temporaryPath, finalPath);
}

async function readLocalSpanIDs(eventsFile, inboxFile) {
  return new Set([
    ...await readJSONArraySpanIDs(eventsFile),
    ...await readQueuedInboxSpanIDs(inboxFile),
    ...await readJSONLSpanIDs(join(dirname(inboxFile), "events-inbox.jsonl")),
  ]);
}

async function readJSONArraySpanIDs(path) {
  try {
    const parsed = JSON.parse(await readFile(path, "utf8"));
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map((event) => event?.span_id)
      .filter((spanID) => typeof spanID === "string");
  } catch {
    return [];
  }
}

async function readJSONLSpanIDs(path) {
  let contents = "";
  try {
    contents = await readFile(path, "utf8");
  } catch {
    return [];
  }

  const spanIDs = [];
  for (const line of contents.split(/\r?\n/)) {
    if (line.trim().length === 0) continue;
    const parsed = safeJSON(line);
    if (typeof parsed?.span_id === "string") {
      spanIDs.push(parsed.span_id);
    }
  }
  return spanIDs;
}

async function readQueuedInboxSpanIDs(path) {
  let files = [];
  try {
    files = await readdir(path);
  } catch {
    return [];
  }

  const spanIDs = [];
  for (const file of files) {
    if (!file.endsWith(".json") || file.startsWith(".")) continue;
    const parsed = safeJSON(await readFile(join(path, file), "utf8").catch(() => ""));
    if (typeof parsed?.span_id === "string") {
      spanIDs.push(parsed.span_id);
    }
  }
  return spanIDs;
}

async function readState(path) {
  try {
    const parsed = JSON.parse(await readFile(path, "utf8"));
    if (parsed && Array.isArray(parsed.sentSpanIDs)) {
      return {
        updatedAt: typeof parsed.updatedAt === "string" ? parsed.updatedAt : "",
        sentSpanIDs: parsed.sentSpanIDs.filter((value) => typeof value === "string"),
        sessionCursors: plainObject(parsed.sessionCursors) ? parsed.sessionCursors : {},
      };
    }
  } catch {
    // Missing or corrupt state should not block local metering.
  }
  return { updatedAt: "", sentSpanIDs: [], sessionCursors: {} };
}

async function readRuntimeLabel(path, expectedTool) {
  let parsed = null;
  try {
    parsed = JSON.parse(await readFile(path, "utf8"));
  } catch {
    return {};
  }

  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};
  const tool = typeof parsed.ai_tool === "string" ? parsed.ai_tool : "";
  if (tool && tool !== "unknown" && tool !== expectedTool) return {};

  const updatedAt = optionalDate(parsed.updated_at);
  const expiresAt = optionalDate(parsed.expires_at);
  if (typeof parsed.updated_at === "string" && parsed.updated_at.length > 0 && !updatedAt) return {};
  if (typeof parsed.expires_at === "string" && parsed.expires_at.length > 0 && !expiresAt) return {};

  return {
    taskType: optionalWorkflowSlug(parsed.task_type),
    stage: optionalWorkflowSlug(parsed.stage),
    projectID: optionalOpaqueID(parsed.project_id),
    hasLabel: Boolean(optionalWorkflowSlug(parsed.task_type) || optionalWorkflowSlug(parsed.stage)),
    updatedAt,
    expiresAt,
  };
}

function labelForTimestamp(label, timestamp) {
  if (!label?.hasLabel) return {};
  if (!(timestamp instanceof Date) || Number.isNaN(timestamp.getTime())) return {};
  if (label.updatedAt && timestamp < label.updatedAt) return {};
  if (label.expiresAt && timestamp > label.expiresAt) return {};
  return {
    taskType: label.taskType,
    stage: label.stage,
    projectID: label.projectID,
  };
}

function optionalDate(value) {
  if (typeof value !== "string" || value.length === 0) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function optionalOpaqueID(value) {
  return typeof value === "string" && /^[A-Za-z0-9_-]{6,64}$/.test(value)
    ? value
    : null;
}

async function writeState(path, state) {
  await mkdir(dirname(path), { recursive: true, mode: 0o700 });
  await writeFile(path, `${JSON.stringify(state, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
}

async function safeReadDir(path) {
  return readdir(path).catch(() => []);
}

function parseArgs(args) {
  const parsed = {
    json: false,
    dryRun: false,
    strict: false,
    watch: false,
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--json") parsed.json = true;
    else if (arg === "--dry-run") parsed.dryRun = true;
    else if (arg === "--mark-existing") parsed.markExisting = true;
    else if (arg === "--strict") parsed.strict = true;
    else if (arg === "--watch") parsed.watch = true;
    else if (arg === "--codex-home") parsed.codexHome = requiredValue(args, ++index, arg);
    else if (arg === "--endpoint") parsed.endpoint = requiredValue(args, ++index, arg);
    else if (arg === "--transport") parsed.transport = requiredValue(args, ++index, arg);
    else if (arg === "--inbox") parsed.inboxPath = requiredValue(args, ++index, arg);
    else if (arg === "--events") parsed.eventsPath = requiredValue(args, ++index, arg);
    else if (arg === "--state") parsed.statePath = requiredValue(args, ++index, arg);
    else if (arg === "--label-file") parsed.labelPath = requiredValue(args, ++index, arg);
    else if (arg === "--after") parsed.after = requiredValue(args, ++index, arg);
    else if (arg === "--since-hours") parsed.sinceHours = Number(requiredValue(args, ++index, arg));
    else if (arg === "--interval-ms") parsed.intervalMS = Number(requiredValue(args, ++index, arg));
    else if (arg === "--task-type") parsed.taskType = requiredValue(args, ++index, arg);
    else if (arg === "--stage") parsed.stage = requiredValue(args, ++index, arg);
    else if (arg === "--help") {
      printHelp();
      process.exit(0);
    } else {
      fail(`unknown_arg:${arg}`, true);
    }
  }

  return parsed;
}

function requiredValue(args, index, flag) {
  const value = args[index];
  if (!value || value.startsWith("--")) {
    fail(`missing_value:${flag}`, true);
  }
  return value;
}

function plainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function printHelp() {
  process.stdout.write(`Usage: spill-codex-session-importer.mjs [options]

Options:
  --json                 Print import summary as JSON.
  --dry-run              Parse usage without writing local storage, posting to Spill, or writing state.
  --mark-existing        Record parsed span ids in state without storing them.
  --strict               Exit non-zero when the selected transport is unavailable.
  --watch                Poll Codex sessions continuously. Not needed for hook-based metering.
  --after ISO            Import token_count events at or after this timestamp.
  --since-hours HOURS    Import recent events. Default: 24.
  --interval-ms MS       Poll interval for --watch. Default: 5000.
  --codex-home PATH      Codex home. Default: CODEX_HOME or ~/.codex.
  --transport MODE       file or http. Default: file unless --endpoint is provided.
  --inbox PATH           Local event queue directory. Default: ~/Library/Application Support/Spill/token-metering/events-inbox.
  --events PATH          Local canonical events JSON. Used for file-transport dedupe.
  --endpoint URL         Spill event endpoint for --transport http.
  --state PATH           Import state path.
  --label-file PATH      Short-lived safe task/stage label file.
  --task-type SLUG       Override task_type with a safe workflow slug.
  --stage SLUG           Override stage with a safe workflow slug.

Reads only Codex token_count records and safe opaque session/model metadata.
It does not infer task or stage labels from prompts, commands, tool output,
file paths, diffs, logs, or transcript text. Use --task-type/--stage, the
matching SPILL_TOKEN_USAGE_TASK_TYPE/SPILL_TOKEN_USAGE_STAGE environment
variables, or a short-lived label file only when a trusted workflow or agent
already has safe reusable labels.
`);
}

function sinceDate(hours) {
  const parsed = Number(hours);
  const safeHours = Number.isFinite(parsed) && parsed >= 0 ? parsed : DEFAULT_SINCE_HOURS;
  return new Date(Date.now() - safeHours * 60 * 60 * 1000);
}

function safeToken(value) {
  return Number.isSafeInteger(value) && value > 0 ? value : 0;
}

function safeJSON(value) {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function rawJSONField(source, field) {
  const match = new RegExp(`"${field}"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"`).exec(source);
  if (!match) return "";
  try {
    return JSON.parse(`"${match[1]}"`);
  } catch {
    return match[1];
  }
}

function opaqueHash(value) {
  return createHash("sha256").update(value).digest("hex").slice(0, 24);
}

function safeModel(value) {
  const cleaned = String(value || "codex-unknown").replace(/[^A-Za-z0-9_.:-]/g, "-").slice(0, 80);
  return cleaned.length >= 2 ? cleaned : "codex-unknown";
}

function normalizeToolName(value) {
  if (typeof value !== "string") return "";
  const cleaned = value.toLowerCase().replace(/[^a-z0-9_.:-]/g, "_").slice(0, 80);
  if (cleaned.endsWith(".apply_patch") || cleaned.includes("apply_patch")) return "apply_patch";
  if (cleaned.endsWith(".exec_command") || cleaned.includes("exec_command")) return "exec_command";
  if (cleaned.endsWith(".view_image") || cleaned.includes("view_image")) return "view_image";
  return cleaned;
}

function safeWorkflowSlug(value) {
  if (value === undefined || value === null || value === "") return null;
  if (!/^[a-z][a-z0-9_]{1,40}$/.test(String(value))) {
    fail("invalid_workflow_slug", true);
  }
  return String(value);
}

function optionalWorkflowSlug(value) {
  if (typeof value !== "string") return null;
  return /^[a-z][a-z0-9_]{1,40}$/.test(value) ? value : null;
}

function normalizedTransport(value) {
  const normalized = String(value || "file").toLowerCase();
  if (normalized === "file" || normalized === "http") {
    return normalized;
  }
  fail("invalid_transport", true);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function fail(code, alwaysExit) {
  if (strict || alwaysExit) {
    process.stderr.write(`spill-codex-session-importer: ${code}\n`);
    process.exit(1);
  }
}
