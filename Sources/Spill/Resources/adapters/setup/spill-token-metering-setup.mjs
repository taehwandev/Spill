#!/usr/bin/env node

import { access, chmod, copyFile, mkdir, readFile, rename, stat, writeFile } from "node:fs/promises";
import { constants } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";

const STAMP = new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);
const args = parseArgs(process.argv.slice(2));
const apply = args.apply === true;
const force = args.force === true;
const json = args.json === true;
const installRoot = expandHome(args.installDir ?? join(homedir(), "Library/Application Support/Spill/adapters"));
const sourceRoot = await resolveSourceRoot(args.sourceRoot);
const include = new Set((args.include ?? "codex,claude,antigravity,openai").split(",").map((item) => item.trim()).filter(Boolean));
const workflowHook = args.workflowHook ? expandHome(args.workflowHook) : null;

const adapters = {
  codex: {
    id: "codex",
    title: "Codex",
    source: join("codex", "spill-importer.mjs"),
    destination: join(installRoot, "codex", "spill-importer.mjs"),
    executable: true,
    detect: async () => await exists(join(homedir(), ".codex")) || await commandExists("codex"),
    configure: configureCodex,
  },
  claude: {
    id: "claude",
    title: "Claude Code",
    source: join("claude-code", "spill-hook.py"),
    destination: join(installRoot, "claude-code", "spill-hook.py"),
    executable: true,
    detect: async () => await exists(join(homedir(), ".claude")) || await commandExists("claude"),
    configure: configureClaude,
  },
  antigravity: {
    id: "antigravity",
    title: "Antigravity",
    source: join("antigravity", "spill-hook.py"),
    destination: join(installRoot, "antigravity", "spill-hook.py"),
    executable: true,
    detect: async () => await exists(join(homedir(), ".gemini")) || await commandExists("gemini"),
    configure: configureAntigravity,
  },
  openai: {
    id: "openai",
    title: "OpenAI SDK",
    source: join("openai", "spill-adapter.py"),
    destination: join(installRoot, "openai", "spill-adapter.py"),
    executable: false,
    detect: async () => Boolean(process.env.OPENAI_API_KEY),
    configure: null,
  },
};

const results = [];
for (const adapter of Object.values(adapters)) {
  if (!include.has(adapter.id)) continue;
  const detected = force || await adapter.detect();
  if (!detected) {
    results.push({ tool: adapter.id, action: "skip", reason: "not_detected" });
    continue;
  }

  await installAdapter(adapter);
  if (adapter.configure) {
    await adapter.configure(adapter.destination);
  }
}

if (workflowHook) {
  const adapter = adapters.antigravity;
  await installAdapter(adapter);
  await mergeAgyHookFile(workflowHook, adapter.destination, "workflow");
}

if (json) {
  process.stdout.write(`${JSON.stringify({ apply, source_root: sourceRoot, install_root: installRoot, results }, null, 2)}\n`);
} else {
  for (const result of results) {
    const suffix = result.reason ? ` (${result.reason})` : "";
    process.stdout.write(`${result.action}: ${result.tool}${suffix}\n`);
  }
  if (!apply) {
    process.stdout.write("dry-run: pass --apply to copy adapters and merge hook config files.\n");
  }
}

async function installAdapter(adapter) {
  const source = join(sourceRoot, adapter.source);
  if (!await exists(source)) {
    results.push({ tool: adapter.id, action: "skip", reason: `missing_source:${source}` });
    return;
  }

  if (!apply) {
    results.push({ tool: adapter.id, action: "would_install", path: adapter.destination });
    return;
  }

  await mkdir(dirname(adapter.destination), { recursive: true });
  if (resolve(source) !== resolve(adapter.destination)) {
    await copyFile(source, adapter.destination);
  }
  if (adapter.executable) {
    await chmod(adapter.destination, 0o755);
  }
  results.push({ tool: adapter.id, action: "installed", path: adapter.destination });
}

async function configureCodex(scriptPath) {
  const target = join(homedir(), ".codex", "hooks.json");
  const command = `node ${shellQuote(scriptPath)} --since-hours 6`;
  await mergeStopHookFile(target, command, 30, "codex", /spill-(codex-session-importer|importer)\.mjs/);
}

async function configureClaude(scriptPath) {
  const target = join(homedir(), ".claude", "settings.json");
  const command = `python3 ${shellQuote(scriptPath)}`;
  await mergeStopHookFile(target, command, 5, "claude", /Spill\/adapters\/claude-code\/spill-hook\.py|claude-code\/spill-hook\.py/);
}

async function configureAntigravity(scriptPath) {
  const target = join(homedir(), ".gemini", "config", "hooks.json");
  await mergeAgyHookFile(target, scriptPath, "antigravity");
}

async function mergeStopHookFile(target, command, timeout, tool, match) {
  if (!apply) {
    results.push({ tool, action: "would_configure", path: target });
    return;
  }

  const config = await readJSONObject(target);
  const hooks = plainObject(config.hooks) ? config.hooks : {};
  const stopGroups = Array.isArray(hooks.Stop) ? hooks.Stop : [];
  const cleaned = [];

  for (const group of stopGroups) {
    if (!plainObject(group) || !Array.isArray(group.hooks)) {
      cleaned.push(group);
      continue;
    }
    const remaining = group.hooks.filter((hook) => !plainObject(hook) || typeof hook.command !== "string" || !match.test(hook.command));
    if (remaining.length > 0) {
      cleaned.push({ ...group, hooks: remaining });
    }
  }

  cleaned.push({
    hooks: [
      {
        type: "command",
        command,
        timeout,
      },
    ],
  });

  hooks.Stop = cleaned;
  config.hooks = hooks;
  await writeJSONObject(target, config);
  results.push({ tool, action: "configured", path: target });
}

async function mergeAgyHookFile(target, scriptPath, tool) {
  if (!apply) {
    results.push({ tool, action: "would_configure", path: target });
    return;
  }

  const config = await readJSONObject(target);
  config["spill-metering"] = {
    PostInvocation: [
      {
        matcher: "",
        hooks: [
          {
            type: "command",
            command: `python3 ${shellQuote(scriptPath)}`,
            timeout: 5,
          },
        ],
      },
    ],
  };
  await writeJSONObject(target, config);
  results.push({ tool, action: "configured", path: target });
}

async function readJSONObject(path) {
  if (!await exists(path)) return {};
  const data = await readFile(path, "utf8");
  try {
    const parsed = JSON.parse(data);
    return plainObject(parsed) ? parsed : {};
  } catch {
    throw new Error(`Cannot parse JSON config: ${path}`);
  }
}

async function writeJSONObject(path, value) {
  await mkdir(dirname(path), { recursive: true });
  if (await exists(path)) {
    await copyFile(path, `${path}.spill-backup-${STAMP}`);
  }
  const temporary = `${path}.tmp-${process.pid}`;
  await writeFile(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  await rename(temporary, path);
}

async function resolveSourceRoot(option) {
  if (option) return resolve(expandHome(option));

  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const candidates = [
    join(scriptDir, "..", "Sources", "Spill", "Resources", "adapters"),
    join(scriptDir, ".."),
    scriptDir,
  ];

  for (const candidate of candidates) {
    if (await exists(join(candidate, "codex", "spill-importer.mjs")) ||
        await exists(join(candidate, "claude-code", "spill-hook.py"))) {
      return resolve(candidate);
    }
  }
  return resolve(candidates[0]);
}

async function exists(path) {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

async function commandExists(name) {
  const pathValue = process.env.PATH || "";
  for (const entry of pathValue.split(":")) {
    if (!entry) continue;
    try {
      await access(join(entry, name), constants.X_OK);
      return true;
    } catch {}
  }
  return false;
}

function parseArgs(values) {
  const parsed = {};
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    switch (value) {
    case "--apply":
      parsed.apply = true;
      break;
    case "--force":
      parsed.force = true;
      break;
    case "--json":
      parsed.json = true;
      break;
    case "--help":
    case "-h":
      printHelp();
      process.exit(0);
    case "--include":
      parsed.include = requiredValue(values, ++index, value);
      break;
    case "--install-dir":
      parsed.installDir = requiredValue(values, ++index, value);
      break;
    case "--source-root":
      parsed.sourceRoot = requiredValue(values, ++index, value);
      break;
    case "--workflow-hook":
      parsed.workflowHook = requiredValue(values, ++index, value);
      break;
    default:
      throw new Error(`Unknown option: ${value}`);
    }
  }
  return parsed;
}

function requiredValue(values, index, flag) {
  const value = values[index];
  if (!value || value.startsWith("--")) {
    throw new Error(`Missing value for ${flag}`);
  }
  return value;
}

function printHelp() {
  process.stdout.write(`Usage: spill-token-metering-setup.mjs [options]

Options:
  --apply                 Copy detected adapters and merge hook config files.
  --force                 Install included adapters even when the tool is not detected.
  --include LIST          Comma list: codex,claude,antigravity,openai.
  --workflow-hook PATH    Also add the Antigravity/AGY workflow hook to this selected hooks.json.
  --source-root PATH      Adapter source root. Default: repo or bundled adapters directory.
  --install-dir PATH      Adapter install root. Default: ~/Library/Application Support/Spill/adapters.
  --json                  Print JSON summary.

Default mode is a dry-run. The installer never reads prompts, transcripts,
commands, logs, diffs, source files, environment values, or secrets.
`);
}

function expandHome(path) {
  if (path === "~") return homedir();
  if (path.startsWith("~/")) return join(homedir(), path.slice(2));
  return path;
}

function plainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function shellQuote(value) {
  return `'${value.replaceAll("'", "'\\''")}'`;
}
