#!/usr/bin/env node

import { createHash, randomUUID } from "node:crypto";
import { mkdir, open, readdir, readFile, rename, stat, unlink, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { homedir } from "node:os";

const DEFAULT_PORT = "48731";
const DEFAULT_SINCE_HOURS = 24;
const DEFAULT_WATCH_INTERVAL_MS = 5000;
const MAX_LINE_BYTES = 1024 * 1024;
const STATE_SCHEMA_VERSION = 2;
// A hook run reads only the bytes appended since its last checkpoint. The
// budget bounds a first catch-up pass over an untracked session file so a Stop
// hook never has to finish a full bootstrap inside its timeout; whatever is
// left resumes on the next run instead of being skipped.
const DEFAULT_MAX_SCAN_BYTES = 64 * 1024 * 1024;
const READ_CHUNK_BYTES = 4 * 1024 * 1024;
// A pending line this far past MAX_LINE_BYTES can never parse, so consuming it
// keeps one corrupt session file from stalling every later run.
const MAX_CARRY_BYTES = MAX_LINE_BYTES * 2;
const MAX_TRACKED_SESSION_FILES = 2000;
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

const codexEventSupport = {};
const codexTransportSupport = {};
const codexStateLabelSupport = {
  async readState(path) {
    try {
      const parsed = JSON.parse(await readFile(path, "utf8"));
      if (parsed && Array.isArray(parsed.sentSpanIDs)) {
        return {
          schemaVersion: STATE_SCHEMA_VERSION,
          updatedAt: typeof parsed.updatedAt === "string" ? parsed.updatedAt : "",
          sentSpanIDs: parsed.sentSpanIDs.filter((value) => typeof value === "string"),
          sessionCursors: plainObject(parsed.sessionCursors) ? parsed.sessionCursors : {},
          // Absent in schema 1 state. An empty map just means every session file
          // is still untracked, so the next runs read them forward from zero.
          sessionFiles: sanitizedSessionFiles(parsed.sessionFiles),
        };
      }
    } catch {
      // Missing or corrupt state should not block local metering.
    }
    return {
      schemaVersion: STATE_SCHEMA_VERSION,
      updatedAt: "",
      sentSpanIDs: [],
      sessionCursors: {},
      sessionFiles: {},
    };
  },

  parseRuntimeLabel(parsed, expectedTool) {
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
  },
};

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
const runtimeLabel = await readRuntimeLabelTimeline(labelPath, "codex");

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
const afterDate = options.all
  ? new Date(0)
  : options.after
    ? new Date(options.after)
    : sinceDate(options.sinceHours ?? DEFAULT_SINCE_HOURS);

if (Number.isNaN(afterDate.getTime())) {
  fail("invalid_after", true);
}

const seedOffsets = options.seedOffsets;
// Explicit whole-history passes are install, migration, and repair steps that
// own their own runtime. Only the default hook path is budgeted.
const unboundedScan = Boolean(
  options.bootstrap || options.all || markExisting || options.reconcileExisting,
);
const maxScanBytes = resolveMaxScanBytes(
  options.maxBytes ?? process.env.SPILL_CODEX_IMPORT_MAX_BYTES,
  unboundedScan,
);
// Re-emitting stored spans is only meaningful against whole files, so a
// reconcile pass ignores the checkpoints instead of reading past them.
const rescan = Boolean(options.rescan || options.reconcileExisting);

async function importOnce() {
  const state = await codexStateLabelSupport.readState(statePath);
  const sources = await discoverCodexSessionFiles(codexHome, afterDate);
  const run = {
    state,
    sentSpans: new Set(state.sentSpanIDs),
    storedSpans: dryRun
      ? new Set()
      : transport === "http"
        ? await codexTransportSupport.readBridgeSpanIDs(endpoint)
        : await readLocalSpanIDs(eventsPath, inboxPath),
    emittedSpans: new Set(),
    pending: [],
    unsupportedRecords: { count: 0 },
    diagnostics: { lastUsageEvents: 0, cumulativeDeltaEvents: 0, unsupportedCumulativeOnlyEvents: 0 },
    counts: { scannedFiles: 0, scannedBytes: 0, seededFiles: 0, deferredFiles: 0, importedEvents: 0, markedExisting: 0, skippedSeen: 0 },
    usedRuntimeLabel: false,
    remainingScanBytes: maxScanBytes,
  };

  for (const source of sources) {
    await importSessionSource(run, source);
  }
  if (!dryRun && transport !== "http") {
    await flushPendingEvents(run);
  }

  state.updatedAt = new Date().toISOString();
  if (!dryRun) {
    await writeState(statePath, state);
    if (run.usedRuntimeLabel) await unlink(labelPath).catch(() => {});
  }

  if (options.json) {
    const { counts, diagnostics } = run;
    process.stdout.write(`${JSON.stringify({
      scanned_files: counts.scannedFiles,
      scanned_bytes: counts.scannedBytes,
      seeded_files: counts.seededFiles,
      // Files with bytes left for the next run. Non-zero means the budget or a
      // still-incomplete trailing record stopped this pass, never that data was
      // dropped.
      deferred_files: counts.deferredFiles,
      state_schema_version: STATE_SCHEMA_VERSION,
      imported_events: counts.importedEvents,
      marked_existing: counts.markedExisting,
      skipped_seen: counts.skippedSeen,
      unsupported_records: run.unsupportedRecords.count,
      unsupported_cumulative_only: diagnostics.unsupportedCumulativeOnlyEvents,
      delta_sources: {
        last_usage: diagnostics.lastUsageEvents,
        cumulative_delta: diagnostics.cumulativeDeltaEvents,
      },
      codex_home: codexHome,
      endpoint,
      transport,
      inbox_path: transport === "file" ? inboxPath : undefined,
      dry_run: dryRun,
      all: options.all,
    })}\n`);
  }
}

async function flushPendingEvents(run) {
  if (run.pending.length === 0) return;
  const records = run.pending;
  run.pending = [];
  await codexTransportSupport.appendInboxEvents(inboxPath, records);
}

/// Reads one session file forward from its checkpoint and commits the new
/// checkpoint only after that file's events are durably queued.
async function importSessionSource(run, source) {
  const tracked = trackedSessionFile(run.state, source.path);

  // Seeding is the install/migration step: it marks what is already on disk as
  // read so the first hook run has no backlog. Files that are already tracked
  // keep their checkpoint, so repeating setup never steps over records the hook
  // has not imported yet. Whole-history import stays the app's own job.
  if (seedOffsets) {
    run.counts.scannedFiles += 1;
    if (tracked.seenAt) return;
    run.counts.seededFiles += 1;
    commitSessionFile(run.state, tracked, { offset: source.size, size: source.size });
    return;
  }

  if (run.remainingScanBytes <= 0) {
    run.counts.deferredFiles += 1;
    return;
  }

  const chunk = await readSessionFileChunk(source, tracked, run.remainingScanBytes);
  if (!chunk) {
    // Nothing consumable this run. If bytes remain, they are waiting on a record
    // that is still being written, so report them rather than letting the
    // summary imply the file is fully caught up.
    if (source.size > safeOffset(tracked.offset)) run.counts.deferredFiles += 1;
    return;
  }

  run.counts.scannedFiles += 1;
  run.counts.scannedBytes += chunk.consumedBytes;
  run.remainingScanBytes -= chunk.consumedBytes;
  if (chunk.pendingBytes > 0) run.counts.deferredFiles += 1;

  const records = parseSessionChunk(
    chunk, afterDate, run.state, run.unsupportedRecords, run.diagnostics,
  );
  for (const record of records) {
    await emitSessionRecord(run, record);
  }

  // Queue this file's events before its checkpoint moves. If anything above
  // threw, the offset still points at the last durably queued record, so the
  // next run re-reads those bytes instead of stepping over them.
  if (!dryRun && transport !== "http") {
    await flushPendingEvents(run);
  }
  commitSessionFile(run.state, tracked, {
    offset: chunk.nextOffset,
    size: chunk.size,
    sessionID: chunk.counters.sessionID,
    model: chunk.counters.sessionModel,
    ordinal: chunk.counters.ordinal,
  });
  if (!dryRun) await writeState(statePath, run.state);
}

async function emitSessionRecord(run, record) {
  const event = record.event;
  if (run.emittedSpans.has(event.span_id)
    || (!options.reconcileExisting
      && (run.sentSpans.has(event.span_id) || run.storedSpans.has(event.span_id)))) {
    run.counts.skippedSeen += 1;
    return;
  }

  if (markExisting) {
    run.counts.markedExisting += 1;
  } else if (dryRun) {
    run.counts.importedEvents += 1;
  } else {
    if (transport === "http") {
      await codexTransportSupport.postEvent(endpoint, event);
    } else {
      run.pending.push(record);
      if (run.pending.length >= 5000) await flushPendingEvents(run);
    }
    run.counts.importedEvents += 1;
    run.storedSpans.add(event.span_id);
  }

  if (record.usedRuntimeLabel) run.usedRuntimeLabel = true;
  run.emittedSpans.add(event.span_id);
  if (!run.sentSpans.has(event.span_id)) {
    run.sentSpans.add(event.span_id);
    run.state.sentSpanIDs.push(event.span_id);
    if (run.state.sentSpanIDs.length > 5000) {
      run.state.sentSpanIDs = run.state.sentSpanIDs.slice(-5000);
    }
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
          files.push({ path, size: info.size, modifiedAt: info.mtime.getTime() });
        }
      }
    }
  }
  // Newest first so a budgeted run spends its bytes on the session that is
  // actually being appended to right now.
  return files.sort((left, right) =>
    right.modifiedAt - left.modifiedAt || left.path.localeCompare(right.path));
}

/// Reads the bytes appended to one session file since its stored checkpoint.
///
/// Only whole newline-terminated records are returned. A trailing partial line
/// is left unconsumed so its bytes stay outside the checkpoint until the record
/// is complete on a later run.
async function readSessionFileChunk(source, tracked, budgetBytes) {
  const { path, size } = source;
  let start = safeOffset(tracked.offset);
  let restarted = false;

  // A file shorter than its own checkpoint was truncated or rotated in place,
  // so the stored offset now points into unrelated bytes.
  if (rescan || start > size) {
    start = 0;
    restarted = true;
  }
  if (start === size) return null;

  const counters = restarted
    ? { sessionID: "", sessionModel: "", toolNames: new Set(), ordinal: 0 }
    : {
        sessionID: typeof tracked.sessionID === "string" ? tracked.sessionID : "",
        sessionModel: typeof tracked.model === "string" ? tracked.model : "",
        toolNames: new Set(),
        ordinal: safeOffset(tracked.ordinal),
      };

  // The budget bounds throughput, but a window narrower than one maximal record
  // could never contain a newline, so every run would consume nothing and the
  // file would stall forever. Floor the window at one parseable line so progress
  // is always possible; MAX_LINE_BYTES is the parser's own ceiling, so this
  // reads at most one extra line beyond the budget.
  const allowed = Math.min(size - start, Math.max(budgetBytes, MAX_LINE_BYTES + 1));
  if (allowed <= 0) return null;

  let carry = Buffer.alloc(0);
  let consumed = 0;

  const handle = await open(path, "r").catch(() => null);
  if (!handle) return null;
  try {
    const buffer = Buffer.allocUnsafe(Math.min(READ_CHUNK_BYTES, allowed));
    while (consumed + carry.length < allowed) {
      const want = Math.min(buffer.length, allowed - consumed - carry.length);
      const { bytesRead } = await handle.read(buffer, 0, want, start + consumed + carry.length);
      if (bytesRead <= 0) break;

      const combined = carry.length > 0
        ? Buffer.concat([carry, buffer.subarray(0, bytesRead)])
        : Buffer.from(buffer.subarray(0, bytesRead));
      const boundary = combined.lastIndexOf(0x0a);
      if (boundary < 0) {
        carry = combined;
        // Force progress past a record that could never be parsed anyway.
        if (carry.length > MAX_CARRY_BYTES) {
          consumed += carry.length;
          carry = Buffer.alloc(0);
        }
        continue;
      }

      // Folded per read rather than collected, so peak memory stays at one read
      // buffer instead of every line in the window.
      consumeChunkLines(combined.subarray(0, boundary + 1).toString("utf8"), counters);
      consumed += boundary + 1;
      carry = Buffer.from(combined.subarray(boundary + 1));
    }
  } finally {
    await handle.close().catch(() => {});
  }

  if (consumed === 0) return null;

  return {
    path,
    size,
    counters,
    records: counters.records ?? [],
    consumedBytes: consumed,
    nextOffset: start + consumed,
    pendingBytes: size - (start + consumed),
  };
}

function consumeChunkLines(text, counters) {
  for (const line of text.split(/\r?\n/)) {
    if (line.length > 0) consumeSessionLine(line, counters);
  }
}

/// Folds one JSONL record into the running per-file counters.
function consumeSessionLine(line, counters) {
  if (!line || line.length > MAX_LINE_BYTES) return;
  if (line.includes('"type":"session_meta"') || line.includes('"type": "session_meta"')) {
    captureSessionMeta(line, counters);
    return;
  }
  if (line.includes('"type":"turn_context"') || line.includes('"type": "turn_context"')) {
    const model = rawJSONField(line, "model");
    if (model) counters.sessionModel = model;
    return;
  }
  if (mayContainToolMetadata(line)) {
    collectSafeToolNames(safeJSON(line), counters.toolNames);
  }
  if (!line.includes('"token_count"')) return;

  const parsed = safeJSON(line);
  if (!parsed || parsed.type !== "event_msg" || parsed.payload?.type !== "token_count") {
    return;
  }
  counters.ordinal += 1;
  if (!counters.records) counters.records = [];
  counters.records.push({ raw: parsed, eventIndex: counters.ordinal });
}

function parseSessionChunk(chunk, after, state, unsupportedRecords = { count: 0 }, diagnostics = null) {
  const { path, counters } = chunk;
  const records = [];
  for (const entry of chunk.records) {
    const timestamp = codexEventSupport.parseEventTimestamp(entry.raw.timestamp);
    if (!timestamp) {
      unsupportedRecords.count += 1;
      continue;
    }
    const usage = usageRecordFromTokenCount(entry.raw.payload.info);
    if (!usage) {
      unsupportedRecords.count += 1;
      continue;
    }
    records.push({ timestamp, usage, eventIndex: entry.eventIndex });
  }

  if (records.length === 0) return [];

  const sessionKey = counters.sessionID || path;
  const cursorKey = opaqueHash(sessionKey);
  const fallbackLabel = fallbackLabelFromTools();
  let cursor = state.sessionCursors[cursorKey];
  const parsedRecords = [];

  for (const record of records) {
    const delta = usageDelta(record.usage);
    const nextCursor = cursorFromUsage(record.usage);
    if (shouldAdvanceCursor(cursor, nextCursor)) {
      cursor = nextCursor;
    }

    if (record.timestamp < after) continue;
    if (!delta) {
      unsupportedRecords.count += 1;
      if (!record.usage.last.hasAny && record.usage.total.hasAny) {
        if (diagnostics) diagnostics.unsupportedCumulativeOnlyEvents += 1;
      }
      continue;
    }
    if (delta.source === "last_usage") {
      if (diagnostics) diagnostics.lastUsageEvents += 1;
    } else if (delta.source === "cumulative_delta") {
      if (diagnostics) diagnostics.cumulativeDeltaEvents += 1;
    }

    const eventLabel = labelForTimestamp(runtimeLabel, record.timestamp);
    const usedRuntimeLabel = Boolean(
      (!taskTypeOverride && eventLabel.taskType) ||
        (!stageOverride && eventLabel.stage),
    );
    const event = codexEventSupport.toSpillEvent({
        sourcePath: path,
        sessionID: counters.sessionID,
        eventIndex: record.eventIndex,
        timestamp: record.timestamp,
        model: record.usage.model || counters.sessionModel || "codex-unknown",
        inputTokens: delta.inputTokens,
        outputTokens: delta.outputTokens,
        cumulativeTotal: record.usage.total.totalTokens,
        deltaSource: delta.source,
        projectID: eventLabel.projectID,
        taskType: taskTypeOverride ?? eventLabel.taskType ?? fallbackLabel.taskType,
        stage: stageOverride ?? eventLabel.stage ?? fallbackLabel.stage,
    });
    parsedRecords.push({
      event,
      accounting: codexEventSupport.accountingRecordForEvent(event, delta),
      usedRuntimeLabel,
    });
  }

  if (cursor) {
    state.sessionCursors[cursorKey] = cursor;
  }

  return parsedRecords;
}

codexEventSupport.parseEventTimestamp = function(value) {
  if (typeof value !== "string" || value.length === 0) return null;
  const timestamp = new Date(value);
  return Number.isNaN(timestamp.getTime()) ? null : timestamp;
};

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

function usageDelta(record) {
  let inputTokens = 0;
  let outputTokens = 0;
  let source = "";

  if (record.last.hasAny) {
    inputTokens = record.last.inputTokens;
    outputTokens = record.last.outputTokens;
    source = "last_usage";
  } else {
    return null;
  }

  if (inputTokens === 0 && outputTokens === 0) return null;
  const cacheReadInputTokens = Math.min(record.last.cachedInputTokens, inputTokens);
  return {
    inputTokens,
    outputTokens,
    cacheReadInputTokens,
    uncachedInputTokens: Math.max(0, inputTokens - cacheReadInputTokens),
    cacheCreationInputTokens: 0,
    reasoningOutputTokens: record.last.reasoningTokens,
    source,
  };
}

function cursorFromUsage(record) {
  if (!record.total.hasAny || record.total.totalTokens <= 0) return null;
  return {
    inputTokens: record.total.inputTokens,
    outputTokens: record.total.outputTokens,
    reasoningTokens: record.total.reasoningTokens,
    totalTokens: record.total.totalTokens,
  };
}

codexEventSupport.accountingRecordForEvent = function(event, delta) {
  return {
    schema_version: 1,
    span_id: event.span_id,
    ai_tool: event.ai_tool,
    uncached_input_tokens: delta.uncachedInputTokens,
    cache_creation_input_tokens: delta.cacheCreationInputTokens,
    cache_read_input_tokens: delta.cacheReadInputTokens,
    reasoning_output_tokens: delta.reasoningOutputTokens,
  };
};

function shouldAdvanceCursor(currentCursor, nextCursor) {
  if (!nextCursor) return false;
  if (!currentCursor) return true;
  return nextCursor.totalTokens >= (currentCursor.totalTokens ?? 0);
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

function fallbackLabelFromTools() {
  return { taskType: "uncategorized", stage: "summarize" };
}

codexEventSupport.toSpillEvent = function({
  sourcePath,
  sessionID,
  eventIndex,
  timestamp,
  model,
  inputTokens,
  outputTokens,
  cumulativeTotal,
  deltaSource,
  projectID,
  taskType,
  stage,
}) {
  const totalTokens = inputTokens + outputTokens;
  const sessionKey = sessionID || sourcePath;
  const cumulativeKey = cumulativeTotal > 0 ? String(cumulativeTotal) : String(eventIndex);
  const spanIdentity = deltaSource === "cumulative_delta"
    ? `${sourcePath}:${sessionKey}:cumulative:${cumulativeKey}`
    : `${sourcePath}:${sessionKey}:${cumulativeKey}:${timestamp.toISOString()}`;
  const spanHash = opaqueHash(spanIdentity);
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
};

codexTransportSupport.readBridgeSpanIDs = async function(url) {
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
};

codexTransportSupport.postEvent = async function(url, event) {
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
};

codexTransportSupport.appendInboxEvents = async function(path, records) {
  if (!Array.isArray(records) || records.length === 0) return;
  await mkdir(path, { recursive: true, mode: 0o700 });
  const id = randomUUID();
  const temporaryPath = join(path, `.${id}.tmp`);
  const finalPath = join(path, `${id}.jsonl`);
  const accountingTemporaryPath = join(path, `.${id}.accounting.tmp`);
  const accountingFinalPath = join(path, `${id}.accounting`);
  const events = records.map((record) => record.event ?? record).filter(Boolean);
  const accountingRecords = records.map((record) => record.accounting).filter(Boolean);
  const body = `${events.map((event) => JSON.stringify(event)).join("\n")}\n`;
  await writeFile(temporaryPath, body, {
    encoding: "utf8",
    mode: 0o600,
    flag: "wx",
  });
  if (accountingRecords.length > 0) {
    const accountingBody = `${accountingRecords.map((record) => JSON.stringify(record)).join("\n")}\n`;
    await writeFile(accountingTemporaryPath, accountingBody, {
      encoding: "utf8",
      mode: 0o600,
      flag: "wx",
    });
  }
  if (accountingRecords.length > 0) {
    await rename(accountingTemporaryPath, accountingFinalPath);
  }
  await rename(temporaryPath, finalPath);
};

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
    if (file.startsWith(".")) continue;
    const filePath = join(path, file);
    if (file.endsWith(".json")) {
      const parsed = safeJSON(await readFile(filePath, "utf8").catch(() => ""));
      if (typeof parsed?.span_id === "string") {
        spanIDs.push(parsed.span_id);
      }
    } else if (file.endsWith(".jsonl")) {
      spanIDs.push(...await readJSONLSpanIDs(filePath));
    }
  }
  return spanIDs;
}

async function readRuntimeLabelTimeline(path, expectedTool) {
  const entries = [];
  const current = await readRuntimeLabel(path, expectedTool);
  if (current?.hasLabel) entries.push(current);

  const timelinePath = path.endsWith(".json")
    ? path.slice(0, -".json".length) + "-timeline.jsonl"
    : `${path}-timeline.jsonl`;
  try {
    const raw = await readFile(timelinePath, "utf8");
    for (const line of raw.split(/\r?\n/)) {
      if (!line.trim()) continue;
      try {
        const entry = codexStateLabelSupport.parseRuntimeLabel(JSON.parse(line), expectedTool);
        if (entry?.hasLabel) entries.push(entry);
      } catch {
        // Ignore corrupt timeline lines; labels are optional metadata.
      }
    }
  } catch {
    // Missing timelines are expected on fresh installs.
  }

  return { hasLabel: entries.length > 0, entries };
}

async function readRuntimeLabel(path, expectedTool) {
  try {
    return codexStateLabelSupport.parseRuntimeLabel(JSON.parse(await readFile(path, "utf8")), expectedTool) ?? {};
  } catch {
    return {};
  }
}

function labelForTimestamp(labelTimeline, timestamp) {
  if (!labelTimeline?.hasLabel || !Array.isArray(labelTimeline.entries)) return {};
  if (!(timestamp instanceof Date) || Number.isNaN(timestamp.getTime())) return {};
  let label = null;
  for (const entry of labelTimeline.entries) {
    if (!entry.updatedAt || !entry.expiresAt) continue;
    if (entry.updatedAt && timestamp < entry.updatedAt) continue;
    if (entry.expiresAt && timestamp > entry.expiresAt) continue;
    if (!label || (entry.updatedAt && (!label.updatedAt || entry.updatedAt > label.updatedAt))) {
      label = entry;
    }
  }
  if (!label) return {};
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
  // Rename in the same directory so a run interrupted mid-write leaves the
  // previous checkpoint intact rather than a truncated one.
  const temporaryPath = `${path}.${process.pid}-${randomUUID().slice(0, 8)}.tmp`;
  await writeFile(temporaryPath, `${JSON.stringify(state, null, 2)}\n`, {
    encoding: "utf8",
    mode: 0o600,
    flag: "wx",
  });
  await rename(temporaryPath, path);
}

/// Rebuilds the per-file checkpoint map, dropping anything unrecognized.
///
/// Only opaque and safe metadata is kept: files are keyed by a hash of their
/// path, never the path itself, and the retained values are Codex's own opaque
/// session id and its model id.
function sanitizedSessionFiles(value) {
  if (!plainObject(value)) return {};
  const files = {};
  for (const [key, entry] of Object.entries(value)) {
    if (!/^[a-f0-9]{24}$/.test(key) || !plainObject(entry)) continue;
    files[key] = {
      offset: safeOffset(entry.offset),
      size: safeOffset(entry.size),
      sessionID: optionalOpaqueID(entry.sessionID) ?? "",
      model: typeof entry.model === "string" ? safeModel(entry.model) : "",
      ordinal: safeOffset(entry.ordinal),
      seenAt: typeof entry.seenAt === "string" ? entry.seenAt : "",
    };
  }
  return files;
}

function trackedSessionFile(state, path) {
  const key = opaqueHash(path);
  const entry = state.sessionFiles[key];
  return plainObject(entry)
    ? { key, ...entry }
    : { key, offset: 0, size: 0, sessionID: "", model: "", ordinal: 0, seenAt: "" };
}

function commitSessionFile(state, tracked, next) {
  state.sessionFiles[tracked.key] = {
    offset: safeOffset(next.offset),
    size: safeOffset(next.size),
    sessionID: optionalOpaqueID(next.sessionID ?? tracked.sessionID) ?? "",
    model: next.model ? safeModel(next.model) : tracked.model || "",
    ordinal: safeOffset(next.ordinal ?? tracked.ordinal),
    seenAt: new Date().toISOString(),
  };
  pruneSessionFiles(state);
}

/// Keeps the checkpoint map bounded. Evicted files are simply untracked again,
/// so they are re-read forward rather than skipped.
function pruneSessionFiles(state) {
  const keys = Object.keys(state.sessionFiles);
  if (keys.length <= MAX_TRACKED_SESSION_FILES) return;
  keys
    .sort((left, right) =>
      String(state.sessionFiles[left].seenAt).localeCompare(String(state.sessionFiles[right].seenAt)))
    .slice(0, keys.length - MAX_TRACKED_SESSION_FILES)
    .forEach((key) => delete state.sessionFiles[key]);
}

function safeOffset(value) {
  return Number.isSafeInteger(value) && value > 0 ? value : 0;
}

function resolveMaxScanBytes(value, unbounded) {
  if (value === undefined || value === null || value === "") {
    return unbounded ? Number.POSITIVE_INFINITY : DEFAULT_MAX_SCAN_BYTES;
  }
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    fail("invalid_max_bytes", true);
  }
  return parsed;
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
    all: false,
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--json") parsed.json = true;
    else if (arg === "--dry-run") parsed.dryRun = true;
    else if (arg === "--all") parsed.all = true;
    else if (arg === "--mark-existing") parsed.markExisting = true;
    else if (arg === "--reconcile-existing") parsed.reconcileExisting = true;
    else if (arg === "--bootstrap") parsed.bootstrap = true;
    else if (arg === "--seed-offsets") parsed.seedOffsets = true;
    else if (arg === "--rescan") parsed.rescan = true;
    else if (arg === "--max-bytes") parsed.maxBytes = requiredValue(args, ++index, arg);
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
  --reconcile-existing   Re-emit existing span ids so the app store can repair numeric usage fields.
  --strict               Exit non-zero when the selected transport is unavailable.
  --watch                Poll Codex sessions continuously. Not needed for hook-based metering.
  --all                  Scan all supported local session history.
  --bootstrap            Explicit install/migration pass. Reads without the per-run byte budget.
  --seed-offsets         Mark session files already on disk as read. Records checkpoints only.
  --rescan               Ignore stored checkpoints and re-read selected files from the start.
  --max-bytes BYTES      Per-run scan budget. Default: 67108864 unless a whole-history flag is set.
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

Session files are read incrementally. Each file keeps a byte checkpoint keyed by
an opaque hash of its path, so a run parses only the records appended since the
previous run. Checkpoints advance only past whole newline-terminated records
that were queued successfully, and reset to the start when a file is truncated
or rotated. Source paths are never stored in state.

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

function fail(code, alwaysExit) {
  if (strict || alwaysExit) {
    process.stderr.write(`spill-codex-session-importer: ${code}\n`);
    process.exit(1);
  }
}
