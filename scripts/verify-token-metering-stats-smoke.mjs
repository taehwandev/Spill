#!/usr/bin/env node
// CLI regressions use only synthetic databases inside throwaway app-owned paths.
import assert from "node:assert/strict";
import { test } from "node:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, readFileSync, rmSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const helper = process.env.SPILL_STATS_HELPER ?? join(repo, "scripts/spill-token-metering-stats.mjs");
const quote = (value) => value === null ? "NULL" : `'${String(value).replaceAll("'", "''")}'`;
const now = new Date().toISOString();

function fixture(t, { accounting = true, runID = true, rows = [] } = {}) {
  const home = mkdtempSync(join(tmpdir(), "spill-stats-test-"));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  const root = join(home, "Library/Application Support/Spill");
  mkdirSync(join(root, "token-metering"), { recursive: true });
  const database = join(root, "token-metering/events.sqlite3");
  const columns = [
    "ai_tool TEXT", "model TEXT", "task_type TEXT", "stage TEXT", "created_at TEXT",
    "total_tokens INTEGER", "payload_json BLOB", "source_system INTEGER", "source_user INTEGER",
    "source_history INTEGER", "source_repo_context INTEGER", "source_tool_output INTEGER",
    "source_generated_output INTEGER", "source_unknown INTEGER",
    ...(runID ? ["run_id TEXT"] : []),
    ...(accounting ? ["accounting_uncached_input_tokens INTEGER", "accounting_cache_creation_input_tokens INTEGER", "accounting_cache_read_input_tokens INTEGER"] : []),
  ];
  const inserts = rows.map((row) => {
    const total = row.input + row.output;
    const values = [row.tool ?? "claude", "model-safe", "debugging", "implement", row.at ?? now,
      total, JSON.stringify({ input_tokens: row.input, output_tokens: row.output, prompt: "PRIVATE_SYNTHETIC_PROMPT" }),
      0, 0, 0, 0, 0, 0, total,
      ...(runID ? [row.run ?? "run_aaaaaaaaaaaa"] : []),
      ...(accounting ? [row.fresh ?? null, row.write ?? null, row.read ?? null] : [])];
    return `INSERT INTO token_usage_events VALUES (${values.map(quote).join(",")});`;
  });
  execFileSync("sqlite3", [database, `CREATE TABLE token_usage_events (${columns.join(",")}); ${inserts.join(" ")}`]);
  return {
    database, home,
    report(extra = [], text = false, executable = helper) {
      const stdout = execFileSync(process.execPath, [executable, "--database", database, "--since", "all", ...(text ? [] : ["--json"]), ...extra], {
        encoding: "utf8", env: { ...process.env, HOME: home, SPILL_AI_TOOL: "codex", SPILL_TOKEN_USAGE_AI_TOOL: "codex" },
      });
      return text ? stdout : JSON.parse(stdout);
    },
  };
}

const comparableRows = [
  { input: 1000, output: 100, fresh: 100, write: 200, read: 700 },
  { input: 600, output: 50, fresh: 100, write: 0, read: 500 },
  { input: 400, output: 20, run: "run_bbbbbbbbbbbb" },
  { tool: "codex", input: 300, output: 30, fresh: 100, write: 0, read: 200 },
  { tool: "codex", input: 200, output: 20, fresh: 50, write: 0, read: 150, run: "run_cccccccccccc" },
];

test("setup installs both stats modules and the installed helper reads exact fixture totals", (t) => {
  const store = fixture(t, { rows: comparableRows });
  mkdirSync(join(store.home, ".codex"), { recursive: true });
  const installRoot = join(store.home, "Library/Application Support/Spill/adapters");
  execFileSync(process.execPath, [join(repo, "scripts/spill-token-metering-setup.mjs"),
    "--home", store.home, "--apply", "--metering-only", "--include", "codex",
    "--install-dir", installRoot, "--source-root", join(repo, "Sources/Spill/Resources/adapters"),
    "--runtime-instruction-source", join(repo, "docs/token-metering/runtime-instruction.md"), "--json"],
    { encoding: "utf8" });
  const installed = join(installRoot, "setup/spill-token-metering-stats.mjs");
  for (const name of ["spill-token-metering-stats-accounting.mjs", "spill-token-metering-stats-presentation.mjs"]) {
    const module = join(installRoot, "setup", name);
    assert.equal(readFileSync(module, "utf8"), readFileSync(join(repo, "scripts", name), "utf8"));
  }
  const report = store.report(["--all"], false, installed);
  assert.equal(report.summary.total_tokens, 2720);
  assert.equal(report.input_accounting.cache_read_tokens, 1550);
  assert.equal(report.sessions.top.length, 4);
});

test("raw totals remain exact while accounting and comparison subtotals expose coverage", (t) => {
  const store = fixture(t, { rows: comparableRows });
  const report = store.report(["--tool", "claude"]);
  assert.equal(report.summary.total_tokens, 2170);
  assert.equal(report.summary.input_tokens, 2000);
  assert.equal(report.summary.output_tokens, 170);
  assert.equal(report.summary.events, 3);
  assert.equal(report.summary.peak_event_tokens, 1100);
  assert.deepEqual(report.input_accounting.available_fields, ["fresh", "cache_write", "cache_read"]);
  assert.equal(report.input_accounting.fresh_tokens, 200);
  assert.equal(report.input_accounting.cache_write_tokens, 200);
  assert.equal(report.input_accounting.cache_read_tokens, 1200);
  assert.equal(report.input_accounting.unclassified_tokens, 400);
  assert.equal(report.input_accounting.input_coverage, 0.8);
  assert.equal(report.input_accounting.event_coverage, 2 / 3);
  assert.equal(report.input_accounting.cache_read_share_of_all_input, 0.6);
  assert.equal(report.input_accounting.cache_read_share_of_classified_input, 0.75);
  assert.equal(report.input_accounting.fresh_plus_output_subtotal, 370);
  assert.equal(report.input_accounting.reference_weighted_subtotal, 740);
  assert.equal(report.input_accounting.complete, false);
  assert.deepEqual(report.input_accounting.reference_weights, { fresh: 1, cache_write: 1.25, cache_read: 0.1, output: 1 });
  assert.equal(report.context_size.avg_input_tokens_per_event, 2000 / 3);
  assert.equal(report.context_size.max_input_tokens_per_event, 1000);
  assert.match(report.context_size.note, /proxy.*not an exact context window/);
  const text = store.report(["--tool", "claude"], true);
  for (const expected of [/Fresh 200/, /Cache write 200/, /Cache read 1.2K/, /Unclassified 400/,
    /incomplete input coverage/, /not model pricing or dollar cost/, /Average 667 \| Maximum 1.0K/,
    /Models/, /Tasks/, /Stages/, /Detail Quality/, /Recent Activity/]) assert.match(text, expected);
});

test("sessions are grouped by tool and run with per-tool ranking and exact shares", (t) => {
  const report = fixture(t, { rows: comparableRows }).report(["--all", "--limit", "1"]);
  assert.equal(report.summary.total_tokens, 2720);
  assert.equal(report.sessions.top.length, 2);
  const claude = report.sessions.top.find((row) => row.ai_tool === "claude");
  const codex = report.sessions.top.find((row) => row.ai_tool === "codex");
  assert.equal(claude.run_id, "run_aaaaaaaaaaaa");
  assert.equal(codex.run_id, claude.run_id);
  assert.equal(claude.total_tokens, 1750);
  assert.equal(claude.input_tokens, 1600);
  assert.equal(claude.output_tokens, 150);
  assert.equal(claude.events, 2);
  assert.equal(claude.token_share_of_tool, 1750 / 2170);
  assert.equal(codex.total_tokens, 330);
  assert.equal(codex.token_share_of_tool, 330 / 550);
  assert.equal(report.sessions.opaque_id_events, 5);
  const accounting = report.input_accounting.by_tool.find((row) => row.ai_tool === "codex");
  assert.equal(accounting.reference_weighted_subtotal, 235);
  assert.equal(accounting.fresh_plus_output_subtotal, 200);
  assert.equal(accounting.complete, true);
});

test("old schema leaves all input unclassified and does not invent sessions", (t) => {
  const report = fixture(t, { accounting: false, runID: false, rows: [{ input: 900, output: 100 }] }).report(["--tool", "claude"]);
  assert.equal(report.summary.total_tokens, 1000);
  assert.equal(report.input_accounting.schema_available, false);
  assert.deepEqual(report.input_accounting.available_fields, []);
  assert.equal(report.input_accounting.fresh_tokens, 0);
  assert.equal(report.input_accounting.unclassified_tokens, 900);
  assert.equal(report.input_accounting.input_coverage, 0);
  assert.equal(report.input_accounting.fresh_plus_output_subtotal, 100);
  assert.equal(report.input_accounting.reference_weighted_subtotal, 100);
  assert.equal(report.input_accounting.complete, false);
  assert.equal(report.sessions.available, false);
  assert.equal(report.sessions.unattributed_events, 1);
  assert.deepEqual(report.sessions.top, []);
});

test("missing, negative, fractional and overcounted accounting stays unclassified", (t) => {
  const rows = [
    { input: 100, output: 10, fresh: 100, write: 0 },
    { input: 100, output: 10, fresh: -1, write: 0, read: 101 },
    { input: 100, output: 10, fresh: 1.5, write: 0, read: 98.5 },
    { input: 100, output: 10, fresh: 100, write: 0, read: 1 },
    { input: 100, output: 10, fresh: 20, write: 10, read: 50 },
  ];
  const accounting = fixture(t, { rows }).report(["--tool", "claude"]).input_accounting;
  assert.equal(accounting.fresh_tokens, 20);
  assert.equal(accounting.cache_write_tokens, 10);
  assert.equal(accounting.cache_read_tokens, 50);
  assert.equal(accounting.unclassified_tokens, 420);
  assert.equal(accounting.events_with_accounting, 1);
  assert.equal(accounting.complete_events, 0);
  assert.equal(accounting.input_coverage, 0.16);
  assert.equal(accounting.fresh_plus_output_subtotal, 70);
  assert.equal(accounting.reference_weighted_subtotal, 87.5);
});

test("tool and date filters also apply to accounting, context and sessions", (t) => {
  const store = fixture(t, { rows: [...comparableRows, {
    input: 2000, output: 500, fresh: 2000, write: 0, read: 0, run: "run_dddddddddddd", at: "1999-01-01T00:00:00Z",
  }] });
  const report = store.report(["--tool", "claude", "--since", "24h"]);
  assert.equal(report.summary.events, 3);
  assert.equal(report.context_size.max_input_tokens_per_event, 1000);
  assert.equal(report.input_accounting.fresh_tokens, 200);
  assert.equal(report.sessions.top.length, 2);
  assert.ok(report.sessions.top.every((row) => row.ai_tool === "claude"));
  const self = store.report();
  assert.equal(self.scope.tool, "codex");
  assert.equal(self.summary.total_tokens, 550);
});

test("private payload fields and unsafe run IDs never appear in either report format", (t) => {
  const store = fixture(t, { rows: [...comparableRows, {
    input: 80, output: 8, run: "/private/PRIVATE_SYNTHETIC_TITLE",
  }] });
  const report = store.report(["--tool", "claude"]);
  assert.equal(report.summary.total_tokens, 2258);
  assert.equal(report.sessions.unattributed_events, 1);
  assert.equal(report.sessions.top[0].token_share_of_tool, 1750 / 2258);
  const output = JSON.stringify(report) + store.report(["--tool", "claude"], true);
  assert.doesNotMatch(output, /PRIVATE_SYNTHETIC|\/private\/|payload_json|prompt|command|repo_name|branch_name|title/);
  const invalid = join(store.home, "outside.sqlite3");
  execFileSync("sqlite3", [invalid, "CREATE TABLE private_content (value TEXT); INSERT INTO private_content VALUES ('PRIVATE_SYNTHETIC_OUTSIDE');"]);
  const rejected = store.report(["--database", invalid]);
  assert.equal(rejected.reason, "database_outside_app_data");
  assert.equal(rejected.summary.events, 0);
  assert.doesNotMatch(JSON.stringify(rejected), /PRIVATE_SYNTHETIC_OUTSIDE|outside.sqlite3/);
});

test("shipped helpers match repository copies and an empty store remains usable", (t) => {
  for (const name of ["spill-token-metering-stats.mjs", "spill-token-metering-stats-accounting.mjs", "spill-token-metering-stats-presentation.mjs"]) {
    assert.equal(readFileSync(join(repo, "scripts", name), "utf8"), readFileSync(join(repo, "Sources/Spill/Resources/adapters/setup", name), "utf8"));
    assert.equal(readFileSync(join(repo, "scripts", name), "utf8"), readFileSync(join(repo, "adapters/setup", name), "utf8"));
    assert.ok(readFileSync(join(repo, "docs/token-metering/install.sh"), "utf8").includes(`download "adapters/setup/${name}"`));
  }
  const report = fixture(t).report(["--all"]);
  assert.equal(report.summary.total_tokens, 0);
  assert.equal(report.input_accounting.unclassified_tokens, 0);
  assert.equal(report.context_size.avg_input_tokens_per_event, 0);
  assert.deepEqual(report.sessions.top, []);
});
