#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { existsSync, realpathSync, statSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { homedir } from "node:os";

const args = parseArgs(process.argv.slice(2));
const json = args.json === true;
const limit = clampInteger(args.limit ?? "5", 1, 20);
const databasePath = resolve(expandHome(args.database ?? defaultDatabasePath()));
const tool = selectTool(args);
const range = selectRange(args.since ?? "today");

try {
  const report = buildReport({ databasePath, tool, range, limit });
  if (json) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } else {
    process.stdout.write(`${formatReport(report)}\n`);
  }
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  if (json) {
    process.stdout.write(`${JSON.stringify({ schema_version: 1, ok: false, error: message }, null, 2)}\n`);
  } else {
    process.stderr.write(`Spill local usage stats failed: ${message}\n`);
  }
  process.exitCode = 1;
}

function buildReport({ databasePath, tool, range, limit }) {
  const generatedAt = new Date();
  const scope = {
    tool: tool ?? "all",
    self_scoped: args.self === true || !args.tool,
  };
  const rangeInfo = {
    key: range.key,
    label: range.label,
    start_at: range.startAt,
    generated_at: generatedAt.toISOString(),
  };

  if (!existsSync(databasePath)) {
    return emptyReport({ scope, rangeInfo, reason: "store_not_found" });
  }
  const databaseValidation = validateDatabasePath(databasePath);
  if (!databaseValidation.ok) {
    return emptyReport({ scope, rangeInfo, reason: databaseValidation.reason });
  }
  if (!tableExists(databasePath)) {
    return emptyReport({ scope, rangeInfo, reason: "events_table_not_found" });
  }

  const where = buildWhere({ tool, startAt: range.startAt });
  const summary = one(sqliteJSON(databasePath, summarySQL(where))) ?? {};
  const models = sqliteJSON(databasePath, groupSQL(where, "model", limit));
  const tasks = sqliteJSON(databasePath, groupSQL(where, "task_type", limit));
  const stages = sqliteJSON(databasePath, groupSQL(where, "stage", limit));
  const sources = sourceRows(summary);
  const activity = sqliteJSON(databasePath, activitySQL(where, range.activityLimit)).reverse();

  return {
    schema_version: 1,
    ok: true,
    scope,
    range: rangeInfo,
    summary: normalizeSummary(summary),
    models,
    tasks,
    stages,
    sources,
    activity,
  };
}

function emptyReport({ scope, rangeInfo, reason }) {
  return {
    schema_version: 1,
    ok: true,
    reason,
    scope,
    range: rangeInfo,
    summary: normalizeSummary({}),
    models: [],
    tasks: [],
    stages: [],
    sources: [],
    activity: [],
  };
}

function summarySQL(where) {
  return `
    SELECT
      COUNT(*) AS events,
      COALESCE(SUM(total_tokens), 0) AS total_tokens,
      COALESCE(SUM(CAST(json_extract(CAST(payload_json AS TEXT), '$.input_tokens') AS INTEGER)), 0) AS input_tokens,
      COALESCE(SUM(CAST(json_extract(CAST(payload_json AS TEXT), '$.output_tokens') AS INTEGER)), 0) AS output_tokens,
      COALESCE(ROUND(AVG(total_tokens)), 0) AS avg_tokens,
      COALESCE(MAX(total_tokens), 0) AS peak_event_tokens,
      COALESCE(SUM(source_system), 0) AS source_system,
      COALESCE(SUM(source_user), 0) AS source_user,
      COALESCE(SUM(source_history), 0) AS source_history,
      COALESCE(SUM(source_repo_context), 0) AS source_repo_context,
      COALESCE(SUM(source_tool_output), 0) AS source_tool_output,
      COALESCE(SUM(source_generated_output), 0) AS source_generated_output,
      COALESCE(SUM(source_unknown), 0) AS source_unknown,
      COALESCE(SUM(CASE
        WHEN COALESCE(task_type, '') != 'uncategorized'
          OR COALESCE(stage, '') != 'summarize'
        THEN 1 ELSE 0
      END), 0) AS workflow_labeled_events,
      COALESCE(SUM(CASE
        WHEN COALESCE(task_type, '') != 'uncategorized'
          OR COALESCE(stage, '') != 'summarize'
        THEN total_tokens ELSE 0
      END), 0) AS workflow_labeled_tokens,
      MIN(created_at) AS first_event_at,
      MAX(created_at) AS last_event_at
    FROM token_usage_events
    ${where};
  `;
}

function groupSQL(where, column, limit) {
  const safeColumn = assertKnownColumn(column);
  return `
    SELECT
      COALESCE(NULLIF(${safeColumn}, ''), 'unknown') AS label,
      COUNT(*) AS events,
      COALESCE(SUM(total_tokens), 0) AS total_tokens,
      COALESCE(SUM(CAST(json_extract(CAST(payload_json AS TEXT), '$.input_tokens') AS INTEGER)), 0) AS input_tokens,
      COALESCE(SUM(CAST(json_extract(CAST(payload_json AS TEXT), '$.output_tokens') AS INTEGER)), 0) AS output_tokens
    FROM token_usage_events
    ${where}
    GROUP BY label
    ORDER BY total_tokens DESC, events DESC, label ASC
    LIMIT ${limit};
  `;
}

function activitySQL(where, limit) {
  return `
    SELECT
      strftime('%Y-%m-%d %H:00', created_at, 'localtime') AS bucket,
      COUNT(*) AS events,
      COALESCE(SUM(total_tokens), 0) AS total_tokens
    FROM token_usage_events
    ${where}
    GROUP BY bucket
    ORDER BY bucket DESC
    LIMIT ${limit};
  `;
}

function tableExists(databasePath) {
  const rows = sqliteJSON(databasePath, `
    SELECT name
    FROM sqlite_master
    WHERE type = 'table' AND name = 'token_usage_events'
    LIMIT 1;
  `);
  return rows.length > 0;
}

function sqliteJSON(databasePath, sql) {
  if (!validateDatabasePath(databasePath).ok) return [];
  const output = execFileSync("sqlite3", ["-readonly", "-json", databasePath, sql], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
  if (!output) return [];
  return JSON.parse(output);
}

function buildWhere({ tool, startAt }) {
  const filters = [];
  if (tool) filters.push(`ai_tool = ${sqlString(tool)}`);
  if (startAt) filters.push(`created_at >= ${sqlString(startAt)}`);
  return filters.length > 0 ? `WHERE ${filters.join(" AND ")}` : "";
}

function sourceRows(summary) {
  return [
    ["system", summary.source_system],
    ["user", summary.source_user],
    ["history", summary.source_history],
    ["repo_context", summary.source_repo_context],
    ["tool_output", summary.source_tool_output],
    ["generated_output", summary.source_generated_output],
    ["unknown", summary.source_unknown],
  ]
    .map(([label, total]) => ({ label, total_tokens: numeric(total) }))
    .filter((row) => row.total_tokens > 0)
    .sort((a, b) => b.total_tokens - a.total_tokens || a.label.localeCompare(b.label));
}

function normalizeSummary(summary) {
  const events = numeric(summary.events);
  const totalTokens = numeric(summary.total_tokens);
  const workflowLabeledEvents = numeric(summary.workflow_labeled_events);
  const workflowLabeledTokens = numeric(summary.workflow_labeled_tokens);

  return {
    events,
    total_tokens: totalTokens,
    input_tokens: numeric(summary.input_tokens),
    output_tokens: numeric(summary.output_tokens),
    avg_tokens: numeric(summary.avg_tokens),
    peak_event_tokens: numeric(summary.peak_event_tokens),
    workflow_labeled_events: workflowLabeledEvents,
    workflow_labeled_tokens: workflowLabeledTokens,
    workflow_label_event_coverage: events > 0 ? workflowLabeledEvents / events : 0,
    workflow_label_token_coverage: totalTokens > 0 ? workflowLabeledTokens / totalTokens : 0,
    first_event_at: summary.first_event_at ?? null,
    last_event_at: summary.last_event_at ?? null,
  };
}

function formatReport(report) {
  const lines = [];
  const titleRange = report.range.label;
  const titleTool = report.scope.tool === "all" ? "all tools" : report.scope.tool;
  lines.push(`Spill Local Usage - ${titleTool} - ${titleRange}`);

  if (report.reason) {
    lines.push(`No local usage data (${report.reason}).`);
    return lines.join("\n");
  }

  const summary = report.summary;
  lines.push(
    `Total ${compact(summary.total_tokens)} | Input ${compact(summary.input_tokens)} | Output ${compact(summary.output_tokens)} | Events ${number(summary.events)}`
  );
  lines.push(
    `Average ${compact(summary.avg_tokens)} / event | Peak ${compact(summary.peak_event_tokens)} | Last ${formatWhen(summary.last_event_at)}`
  );
  lines.push(
    `Label Coverage ${percent(summary.workflow_label_event_coverage)} records | ${percent(summary.workflow_label_token_coverage)} tokens`
  );

  appendSection(lines, "Models", report.models);
  appendSection(lines, "Tasks", report.tasks);
  appendSection(lines, "Stages", report.stages);
  appendSourceSection(lines, report.sources);
  appendActivitySection(lines, report.activity);

  return lines.join("\n");
}

function appendSection(lines, title, rows) {
  lines.push("");
  lines.push(title);
  if (rows.length === 0) {
    lines.push("  none");
    return;
  }
  const max = Math.max(...rows.map((row) => numeric(row.total_tokens)), 1);
  for (const row of rows) {
    lines.push(
      `  ${pad(row.label, 24)} ${compact(row.total_tokens).padStart(8)} ${bar(row.total_tokens, max)} ${number(row.events)} events`
    );
  }
}

function appendSourceSection(lines, rows) {
  lines.push("");
  lines.push("Detail Quality");
  if (rows.length === 0) {
    lines.push("  none");
    return;
  }
  const max = Math.max(...rows.map((row) => numeric(row.total_tokens)), 1);
  for (const row of rows) {
    lines.push(`  ${pad(row.label, 24)} ${compact(row.total_tokens).padStart(8)} ${bar(row.total_tokens, max)}`);
  }
}

function appendActivitySection(lines, rows) {
  lines.push("");
  lines.push("Recent Activity");
  if (rows.length === 0) {
    lines.push("  none");
    return;
  }
  const max = Math.max(...rows.map((row) => numeric(row.total_tokens)), 1);
  for (const row of rows) {
    lines.push(
      `  ${pad(row.bucket, 16)} ${compact(row.total_tokens).padStart(8)} ${bar(row.total_tokens, max)} ${number(row.events)} events`
    );
  }
}

function selectTool(args) {
  if (args.tool) {
    if (args.tool === "all") return null;
    return normalizeTool(args.tool);
  }
  if (args.self === false) return null;
  return currentRuntimeTool();
}

function currentRuntimeTool() {
  const fromEnv = process.env.SPILL_TOKEN_USAGE_AI_TOOL || process.env.SPILL_AI_TOOL;
  if (fromEnv) return normalizeTool(fromEnv);
  return "codex";
}

function normalizeTool(value) {
  const normalized = String(value).trim().toLowerCase();
  if (normalized === "agy" || normalized === "gemini" || normalized === "antigravity-cli") {
    return "antigravity";
  }
  if (normalized === "claude-code" || normalized === "claudecode") {
    return "claude";
  }
  if (normalized === "openai-sdk") {
    return "openai";
  }
  if (!/^[a-z][a-z0-9_]{1,40}$/.test(normalized)) {
    throw new Error(`Invalid tool label: ${value}`);
  }
  return normalized;
}

function selectRange(value) {
  const key = String(value).trim().toLowerCase();
  const now = new Date();
  if (key === "all") return { key, label: "all time", startAt: null, activityLimit: 12 };
  if (key === "today") {
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    return { key, label: "today", startAt: start.toISOString(), activityLimit: 12 };
  }
  const relative = key.match(/^(\d+)(h|d)$/);
  if (relative) {
    const amount = Number(relative[1]);
    const unit = relative[2];
    const ms = unit === "h" ? amount * 60 * 60 * 1000 : amount * 24 * 60 * 60 * 1000;
    return { key, label: `last ${amount}${unit}`, startAt: new Date(now.getTime() - ms).toISOString(), activityLimit: unit === "h" ? 12 : 24 };
  }
  throw new Error(`Invalid --since value: ${value}. Use today, 24h, 7d, 30d, or all.`);
}

function parseArgs(values) {
  const parsed = {};
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    switch (value) {
    case "--self":
      parsed.self = true;
      break;
    case "--all":
      parsed.self = false;
      parsed.tool = "all";
      break;
    case "--json":
      parsed.json = true;
      break;
    case "--tool":
      parsed.tool = requiredValue(values, ++index, value);
      break;
    case "--since":
      parsed.since = requiredValue(values, ++index, value);
      break;
    case "--limit":
      parsed.limit = requiredValue(values, ++index, value);
      break;
    case "--database":
      parsed.database = requiredValue(values, ++index, value);
      break;
    case "--help":
    case "-h":
      printHelp();
      process.exit(0);
    default:
      throw new Error(`Unknown option: ${value}`);
    }
  }
  return parsed;
}

function printHelp() {
  process.stdout.write(`Usage: spill-token-metering-stats.mjs [options]

Options:
  --self             Show only the current runtime tool. Default.
  --tool TOOL        Show a specific tool. Use all for every local tool.
  --all              Shortcut for --tool all.
  --since RANGE      today, 24h, 7d, 30d, or all. Default: today.
  --limit N          Rows per breakdown section. Default: 5.
  --database PATH    Override the local Spill events.sqlite3 path.
  --json             Print JSON instead of a compact text report.

This command is read-only. It reads Spill's app-owned local usage store and
prints aggregate token counts, model/task/stage breakdowns, workflow label coverage,
token detail quality categories, and recent activity. It does not create usage events and does not read prompts,
responses, commands, file paths, logs, diffs, code content, environment
values, or secrets.
`);
}

function defaultDatabasePath() {
  return join(defaultAppDataRoot(), "token-metering/events.sqlite3");
}

function defaultAppDataRoot() {
  return join(homedir(), "Library/Application Support/Spill");
}

function validateDatabasePath(databasePath) {
  try {
    const rootPath = realpathSync(defaultAppDataRoot());
    const resolvedDatabasePath = realpathSync(databasePath);
    const databaseStat = statSync(resolvedDatabasePath);
    if (!databaseStat.isFile()) {
      return { ok: false, reason: "database_not_file" };
    }

    const relativePath = relative(rootPath, resolvedDatabasePath);
    if (relativePath === "" || relativePath.startsWith("..") || resolve(rootPath, relativePath) !== resolvedDatabasePath) {
      return { ok: false, reason: "database_outside_app_data" };
    }

    return { ok: true };
  } catch {
    return { ok: false, reason: "invalid_database_path" };
  }
}

function assertKnownColumn(column) {
  const allowed = new Set(["model", "task_type", "stage"]);
  if (!allowed.has(column)) throw new Error(`Unexpected group column: ${column}`);
  return column;
}

function sqlString(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

function clampInteger(value, min, max) {
  const parsed = Number.parseInt(String(value), 10);
  if (!Number.isFinite(parsed)) return min;
  return Math.min(Math.max(parsed, min), max);
}

function requiredValue(values, index, flag) {
  const value = values[index];
  if (!value || value.startsWith("--")) {
    throw new Error(`Missing value for ${flag}`);
  }
  return value;
}

function one(rows) {
  return Array.isArray(rows) ? rows[0] : undefined;
}

function numeric(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

function number(value) {
  return new Intl.NumberFormat("en-US").format(numeric(value));
}

function compact(value) {
  const number = numeric(value);
  if (Math.abs(number) >= 1_000_000) return `${(number / 1_000_000).toFixed(1)}M`;
  if (Math.abs(number) >= 1_000) return `${(number / 1_000).toFixed(1)}K`;
  return new Intl.NumberFormat("en-US").format(Math.round(number));
}

function percent(value) {
  const ratio = numeric(value);
  if (ratio > 0 && ratio < 0.001) return "<0.1%";
  return `${(ratio * 100).toFixed(1)}%`;
}

function bar(value, max) {
  const width = 18;
  const filled = max > 0 ? Math.max(1, Math.round((numeric(value) / max) * width)) : 0;
  return `[${"#".repeat(filled)}${"-".repeat(width - filled)}]`;
}

function pad(value, width) {
  const text = String(value ?? "unknown");
  return text.length > width ? text.slice(0, width - 1) + "." : text.padEnd(width);
}

function formatWhen(value) {
  if (!value) return "none";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "unknown";
  return date.toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function expandHome(path) {
  if (path === "~") return homedir();
  if (path.startsWith("~/")) return join(homedir(), path.slice(2));
  return path;
}
