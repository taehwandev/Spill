// Test support for the Codex importer regression suite.
//
// Builds throwaway Codex homes, drives the shipped importer against them, and
// reads back its queued events and checkpoint state.

import { chmod, mkdir, mkdtemp, readdir, readFile, rm, stat, truncate, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import { promisify } from "node:util";

const run = promisify(execFile);
const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const importerPath = process.env.SPILL_CODEX_IMPORTER
  ?? join(repoRoot, "adapters", "codex", "spill-importer.mjs");

const EVENT_KEYS = [
  "schema_version", "device_id", "project_id", "artifact_id", "run_id", "span_id",
  "ai_tool", "task_type", "stage", "model", "input_tokens", "output_tokens",
  "total_tokens", "token_breakdown", "latency_ms", "created_at",
].sort();
const BREAKDOWN_KEYS = [
  "system", "user", "history", "repo_context", "tool_output", "generated_output", "unknown",
].sort();

const counters = { failures: 0, passed: 0 };

function check(condition, message) {
  if (condition) {
    counters.passed += 1;
    return;
  }
  counters.failures += 1;
  process.stderr.write(`FAIL: ${message}\n`);
}

function equal(actual, expected, message) {
  check(
    actual === expected,
    `${message} (expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)})`,
  );
}

function metaLine(sessionID, timestamp) {
  return JSON.stringify({
    timestamp: timestamp.toISOString(),
    type: "session_meta",
    originator: "codex_cli_rs",
    session_id: sessionID,
    model: "gpt-5-codex",
  });
}

function usageLine(timestamp, { input, output, totalInput, totalOutput }) {
  return JSON.stringify({
    timestamp: timestamp.toISOString(),
    type: "event_msg",
    payload: {
      type: "token_count",
      info: {
        model: "gpt-5-codex",
        last_token_usage: {
          input_tokens: input,
          cached_input_tokens: 0,
          output_tokens: output,
          reasoning_output_tokens: 0,
          total_tokens: input + output,
        },
        total_token_usage: {
          input_tokens: totalInput,
          cached_input_tokens: 0,
          output_tokens: totalOutput,
          reasoning_output_tokens: 0,
          total_tokens: totalInput + totalOutput,
        },
      },
    },
  });
}

class Workspace {
  constructor(root) {
    this.root = root;
    this.codexHome = join(root, "codex-home");
    this.sessionDir = join(this.codexHome, "sessions", "2026", "07", "28");
    this.inbox = join(root, "inbox");
    this.statePath = join(root, "state.json");
    this.eventsPath = join(root, "events.json");
    this.labelPath = join(root, "label.json");
  }

  static async create(name) {
    const workspace = new Workspace(await mkdtemp(join(tmpdir(), `spill-codex-${name}-`)));
    await mkdir(workspace.sessionDir, { recursive: true });
    await mkdir(workspace.inbox, { recursive: true });
    return workspace;
  }

  sessionPath(name = "rollout-test.jsonl") {
    return join(this.sessionDir, name);
  }

  async writeSession(lines, name) {
    await writeFile(this.sessionPath(name), `${lines.join("\n")}\n`, "utf8");
  }

  async appendSession(text, name) {
    const path = this.sessionPath(name);
    const existing = await readFile(path, "utf8");
    await writeFile(path, existing + text, "utf8");
  }

  async importOnce(extraArgs = []) {
    const args = [
      importerPath,
      "--codex-home", this.codexHome,
      "--transport", "file",
      "--inbox", this.inbox,
      "--events", this.eventsPath,
      "--state", this.statePath,
      "--label-file", this.labelPath,
      "--since-hours", "24",
      "--json",
      ...extraArgs,
    ];
    const { stdout } = await run(process.execPath, args);
    return JSON.parse(stdout);
  }

  async state() {
    return JSON.parse(await readFile(this.statePath, "utf8"));
  }

  async trackedFile(name) {
    const key = createHash("sha256").update(this.sessionPath(name)).digest("hex").slice(0, 24);
    return (await this.state()).sessionFiles?.[key];
  }

  async importedEvents() {
    const events = [];
    for (const entry of await readdir(this.inbox)) {
      if (entry.startsWith(".") || !entry.endsWith(".jsonl")) continue;
      const body = await readFile(join(this.inbox, entry), "utf8");
      for (const line of body.split("\n")) {
        if (line.trim().length > 0) events.push(JSON.parse(line));
      }
    }
    return events;
  }

  async destroy() {
    await chmod(this.inbox, 0o700).catch(() => {});
    await rm(this.root, { recursive: true, force: true });
  }
}

async function withWorkspace(name, body) {
  const workspace = await Workspace.create(name);
  try {
    await body(workspace);
  } finally {
    await workspace.destroy();
  }
}


export {
  EVENT_KEYS,
  BREAKDOWN_KEYS,
  check,
  equal,
  metaLine,
  usageLine,
  Workspace,
  withWorkspace,
  counters,
  runSuite,
};

/// Runs a named suite and exits non-zero when any assertion or case fails.
async function runSuite(tests) {
  for (const [name, body] of tests) {
    try {
      await body();
      process.stdout.write(`ok   ${name}\n`);
    } catch (error) {
      counters.failures += 1;
      process.stderr.write(`ERROR ${name}: ${error?.message ?? error}\n`);
    }
  }
  process.stdout.write(`\n${counters.passed} assertions passed, ${counters.failures} failed\n`);
  if (counters.failures > 0) process.exit(1);
}
