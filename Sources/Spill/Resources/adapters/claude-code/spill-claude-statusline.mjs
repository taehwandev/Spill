#!/usr/bin/env node
// Harvests Claude Code's per-render rate limits for Spill.
//
// Claude Code hands a status line script a JSON payload on stdin that carries
// a `rate_limits` object. That is the only Claude source which refreshes while
// the tool runs: `~/.claude.json`'s cached utilization is rewritten only when
// something fetches usage, so a whole window can be spent without a single new
// reading landing. Reading the status line payload is what lets Spill show a
// current Claude number without the user typing `/usage`.
//
// A status line script owns the whole line, and a machine may already have one.
// This script therefore chains: it forwards the untouched payload to the
// previously configured command and prints that command's output, so wrapping
// it changes what Spill knows and nothing about what the user sees.
//
// Privacy: the payload also carries session context — working directory, model,
// cost, and more. Only numeric limit fields, window identifiers, and reset
// timestamps are extracted. Nothing else is read, and nothing else is written.
//
// Failure policy: a status line must never break the prompt. Every failure path
// exits 0 after printing whatever the chained command produced.

import { spawn } from "node:child_process";
import { mkdir, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

const rawArgs = process.argv.slice(2);
const chainCommand = optionValue("--chain") || process.env.SPILL_STATUSLINE_CHAIN || "";
const outputDirectory = optionValue("--out") || defaultLimitInboxPath();

const payloadText = await readStdin();

// Forward first: Spill's bookkeeping must never delay or replace the line the
// user actually looks at.
const chained = await runChained(chainCommand, payloadText);
if (chained) {
  process.stdout.write(chained);
}

await harvest(payloadText).catch(() => {});
process.exit(0);

async function harvest(text) {
  if (!text.trim()) {
    return;
  }

  let payload;
  try {
    payload = JSON.parse(text);
  } catch {
    await writeDiagnostic({ payloadParsed: false, rateLimitsFound: false, windowCount: 0, shape: "none" });
    return;
  }

  const rateLimits = payload?.rate_limits;
  if (!rateLimits || typeof rateLimits !== "object") {
    await writeDiagnostic({ payloadParsed: true, rateLimitsFound: false, windowCount: 0, shape: "none" });
    return;
  }

  const { windows, shape } = extractWindows(rateLimits);
  await writeDiagnostic({
    payloadParsed: true,
    rateLimitsFound: true,
    windowCount: windows.length,
    shape,
  });

  if (windows.length === 0) {
    return;
  }

  await writeReading({
    schema_version: 1,
    ai_tool: "claude",
    source: "statusline",
    captured_at: new Date().toISOString(),
    windows,
  });
}

// The payload's exact spelling is Claude Code's to choose and has already
// changed once for the cached-utilization state, so windows are recognised by
// the fields a window limit must have rather than by one hardcoded layout.
// Both an object keyed by window name and an array of entries are accepted.
function extractWindows(rateLimits) {
  const entries = Array.isArray(rateLimits)
    ? rateLimits.map((entry) => [entry?.kind ?? entry?.window ?? "", entry])
    : Object.entries(rateLimits);

  const windows = [];
  let shape = Array.isArray(rateLimits) ? "array" : "object";

  for (const [key, value] of entries) {
    if (!value || typeof value !== "object") continue;
    const percent = numeric(value.used_percentage ?? value.used_percent ?? value.percent ?? value.utilization);
    if (percent === null) continue;
    const minutes = windowMinutes(String(key), value);
    if (minutes === null) continue;
    windows.push({
      key: String(key),
      window_minutes: minutes,
      used_percent: Math.max(0, Math.min(100, percent)),
      resets_at: typeof value.resets_at === "string" ? value.resets_at : null,
    });
  }

  if (windows.length === 0) {
    shape = "unrecognized";
  }
  return { windows, shape };
}

// A window length stated by the payload wins; otherwise it is read from the
// window's own name, which is what `five_hour` and `seven_day` are for. An
// unnamed window with no stated length is skipped rather than guessed at,
// because the length decides which chip slot the reading belongs to.
function windowMinutes(key, value) {
  const stated = numeric(value.window_minutes);
  if (stated !== null && stated > 0) {
    return Math.round(stated);
  }
  const name = key.toLowerCase();
  if (name.includes("five_hour") || name.includes("5_hour") || name === "session") {
    return 300;
  }
  if (name.includes("seven_day") || name.includes("7_day") || name.includes("weekly") || name.includes("week")) {
    return 10_080;
  }
  return null;
}

function numeric(value) {
  const parsed = typeof value === "string" ? Number(value) : value;
  return typeof parsed === "number" && Number.isFinite(parsed) ? parsed : null;
}

async function writeReading(reading) {
  await mkdir(outputDirectory, { recursive: true });
  const temporaryPath = join(outputDirectory, `.claude-statusline-${process.pid}.tmp`);
  await writeFile(temporaryPath, JSON.stringify(reading), { encoding: "utf8", mode: 0o600 });
  await rename(temporaryPath, join(outputDirectory, "claude-statusline.json"));
}

// Content-free, like every other Spill adapter diagnostic: fixed booleans, a
// count, and a timestamp. Without it, "Claude Code stopped sending this" and
// "the status line was never wired up" look identical from the outside.
async function writeDiagnostic(record) {
  const directory = join(spillTokenMeteringPath(), "diagnostics");
  await mkdir(directory, { recursive: true });
  const temporaryPath = join(directory, `.claude-statusline-last-${process.pid}.tmp`);
  await writeFile(
    temporaryPath,
    JSON.stringify({
      schema_version: 1,
      ai_tool: "claude",
      kind: "statusline_scan",
      created_at: new Date().toISOString(),
      payload_received: Boolean(payloadText.trim()),
      payload_parsed: record.payloadParsed,
      rate_limits_found: record.rateLimitsFound,
      window_count: record.windowCount,
      payload_shape: record.shape,
      chained: Boolean(chainCommand),
      privacy:
        "Only fixed booleans, counts, and timestamps are stored. No prompts, responses, commands, file paths, logs, diffs, source, environment values, or secrets.",
    }),
    { encoding: "utf8", mode: 0o600 },
  );
  await rename(temporaryPath, join(directory, "claude-statusline-last.json"));
}

function runChained(command, stdinText) {
  if (!command.trim()) {
    return Promise.resolve("");
  }
  return new Promise((resolve) => {
    let child;
    try {
      child = spawn("/bin/sh", ["-c", command], { stdio: ["pipe", "pipe", "ignore"] });
    } catch {
      resolve("");
      return;
    }
    let output = "";
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      output += chunk;
    });
    child.on("error", () => resolve(""));
    child.on("close", () => resolve(output));
    child.stdin.on("error", () => {});
    child.stdin.end(stdinText);
  });
}

function readStdin() {
  return new Promise((resolve) => {
    let text = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => {
      text += chunk;
    });
    process.stdin.on("end", () => resolve(text));
    process.stdin.on("error", () => resolve(text));
  });
}

function optionValue(flag) {
  const index = rawArgs.indexOf(flag);
  if (index < 0) return "";
  const value = rawArgs[index + 1];
  return value && !value.startsWith("--") ? value : "";
}

function spillTokenMeteringPath() {
  return join(homedir(), "Library", "Application Support", "Spill", "token-metering");
}

function defaultLimitInboxPath() {
  return join(spillTokenMeteringPath(), "limit-inbox");
}
