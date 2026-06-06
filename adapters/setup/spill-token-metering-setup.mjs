#!/usr/bin/env node

import { access, chmod, copyFile, mkdir, readFile, rename, stat, writeFile, symlink, unlink } from "node:fs/promises";
import { constants } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";
import { exec } from "node:child_process";
import { promisify } from "node:util";

const execPromise = promisify(exec);

const STAMP = new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);
const args = parseArgs(process.argv.slice(2));
const apply = args.apply === true;
const force = args.force === true;
const json = args.json === true;
const installRoot = expandHome(args.installDir ?? join(homedir(), "Library/Application Support/Spill/adapters"));
const setupHelperPath = join(installRoot, "setup", "spill-token-metering-setup.mjs");
const defaultHookAdapters = "codex,claude,antigravity";
const alwaysInstallAdapters = new Set(defaultHookAdapters.split(","));
const include = new Set((args.include ?? defaultHookAdapters).split(",").map((item) => item.trim()).filter(Boolean));
const workflowHook = args.workflowHook ? expandHome(args.workflowHook) : null;

if (args.label) {
  const label = await writeRuntimeLabel({
    tool: args.label,
    taskType: args.taskType,
    stage: args.stage,
    labelFile: args.labelFile,
    ttlMinutes: args.ttlMinutes,
    ifAbsent: args.ifAbsent === true,
  });
  const action = label.skipped ? "label_exists" : "labeled";
  if (json) {
    process.stdout.write(`${JSON.stringify({ action, ...label }, null, 2)}\n`);
  } else {
    process.stdout.write(`${action}: ${label.tool} ${label.task_type}/${label.stage}\n`);
  }
  process.exit(0);
}

const sourceRoot = await resolveSourceRoot(args.sourceRoot);

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
await installSetupHelper();
for (const adapter of Object.values(adapters)) {
  if (!include.has(adapter.id)) continue;
  const detected = force || alwaysInstallAdapters.has(adapter.id) || await adapter.detect();
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

await configureRuntimeLabelDefaults();

if (json) {
  process.stdout.write(`${JSON.stringify({ apply, source_root: sourceRoot, install_root: installRoot, results }, null, 2)}\n`);
} else {
  for (const result of results) {
    const suffix = result.reason ? ` (${result.reason})` : "";
    process.stdout.write(`${result.action}: ${result.tool}${suffix}\n`);
  }
  if (!apply) {
    process.stdout.write("dry-run: pass --apply to install Codex, Claude Code, and Antigravity/AGY metering in one pass.\n");
  }
}

async function installSetupHelper() {
  if (!apply) {
    results.push({ tool: "setup", action: "would_install", path: setupHelperPath });
    return;
  }

  const source = fileURLToPath(import.meta.url);
  await mkdir(dirname(setupHelperPath), { recursive: true });
  if (resolve(source) !== resolve(setupHelperPath)) {
    await copyFile(source, setupHelperPath);
  }
  await chmod(setupHelperPath, 0o755);
  results.push({ tool: "setup", action: "installed", path: setupHelperPath });
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
  const stopCommand = `SPILL_AI_TOOL=claude python3 ${shellQuote(scriptPath)}`;
  await mergeStopHookFile(target, stopCommand, 5, "claude", /Spill\/adapters\/claude-code\/spill-hook\.py|claude-code\/spill-hook\.py/);
}

async function configureAntigravity(scriptPath) {
  let finalScriptPath = scriptPath;
  const hasSpace = scriptPath.includes(" ");

  if (hasSpace) {
    const symlinkTarget = join(homedir(), ".gemini", "spill-hook.py");
    if (apply) {
      try {
        if (await exists(symlinkTarget)) {
          await unlink(symlinkTarget);
        }
        await symlink(scriptPath, symlinkTarget);
        finalScriptPath = symlinkTarget;
        results.push({ tool: "antigravity", action: "symlink_created", path: symlinkTarget });
      } catch (err) {
        try {
          await copyFile(scriptPath, symlinkTarget);
          await chmod(symlinkTarget, 0o755);
          finalScriptPath = symlinkTarget;
          results.push({ tool: "antigravity", action: "fallback_copied", path: symlinkTarget });
        } catch (copyErr) {
          results.push({ tool: "antigravity", action: "symlink_failed", reason: `${err.message} / ${copyErr.message}` });
        }
      }
    } else {
      finalScriptPath = symlinkTarget;
      results.push({ tool: "antigravity", action: "would_create_symlink", path: symlinkTarget });
    }
  }

  // Write to both paths for robustness across client versions and verification logic
  const targets = [
    join(homedir(), ".gemini", "config", "hooks.json"),
    join(homedir(), ".gemini", "hooks.json"),
    join(homedir(), ".gemini", "antigravity-cli", "hooks.json")
  ];
  for (const target of targets) {
    await mergeAgyHookFile(target, finalScriptPath, "antigravity");
  }

  // Automatically add command permission to ~/.gemini/config/config.json
  if (apply) {
    const configFile = join(homedir(), ".gemini", "config", "config.json");
    try {
      if (await exists(configFile)) {
        const config = await readJSONObject(configFile);
        if (plainObject(config.permissions) && Array.isArray(config.permissions.allow)) {
          const newEntries = agentRuntimePermissionEntries("antigravity", "command");
          let addedCount = 0;
          for (const perm of newEntries) {
            if (!config.permissions.allow.includes(perm)) {
              config.permissions.allow.push(perm);
              addedCount++;
            }
          }
          if (addedCount > 0) {
            await writeJSONObject(configFile, config);
            results.push({ tool: "antigravity", action: "permissions_added", count: addedCount, path: configFile });
          }
        }
      }
    } catch (err) {
      results.push({ tool: "antigravity", action: "permission_failed", reason: err.message });
    }
  } else {
    results.push({ tool: "antigravity", action: "would_add_permissions", path: join(homedir(), ".gemini", "config", "config.json") });
  }
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
    matcher: "",
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
  const command = `python3 ${shellQuote(scriptPath)}`;
  const timeout = 5;
  const match = /spill-hook\.py/;
  const hookName = "spill-metering";
  const namedSpec = plainObject(config[hookName]) ? config[hookName] : {};

  let list = namedSpec.PostInvocation || [];
  if (Array.isArray(list)) {
    list = list.map(group => {
      if (!plainObject(group) || !Array.isArray(group.hooks)) return group;
      const remaining = group.hooks.filter(hook => !plainObject(hook) || typeof hook.command !== "string" || !match.test(hook.command));
      return { ...group, hooks: remaining };
    }).filter(group => Array.isArray(group.hooks) && group.hooks.length > 0);
  } else {
    list = [];
  }

  list.push({
    matcher: "",
    hooks: [
      {
        type: "command",
        command,
        timeout,
      }
    ]
  });

  namedSpec.PostInvocation = list;
  config[hookName] = namedSpec;
  delete config.PostInvocation;

  await writeJSONObject(target, config);
  results.push({ tool, action: "configured", path: target });
}

async function configureRuntimeLabelDefaults() {
  if (include.has("codex")) {
    await configureCodexRuntimeRules();
  }
  if (include.has("claude")) {
    await configureAgentRuntimeSettings({
      tool: "claude",
      target: join(homedir(), ".claude", "settings.json"),
      permissionPrefix: "Bash",
    });
  }
  if (include.has("antigravity")) {
    await configureAgentRuntimeSettings({
      tool: "antigravity",
      target: join(homedir(), ".gemini", "antigravity-cli", "settings.json"),
      permissionPrefix: "command",
    });
  }
}

async function configureCodexRuntimeRules() {
  const target = join(homedir(), ".codex", "rules", "default.rules");
  const block = codexRuntimeRulesBlock();
  if (!apply) {
    results.push({ tool: "codex", action: "would_configure_agent_runtime", path: target });
    return;
  }

  await writeManagedTextBlock({
    path: target,
    begin: "# spill-token-metering:begin",
    end: "# spill-token-metering:end",
    block,
  });
  results.push({ tool: "codex", action: "configured_agent_runtime", path: target });
}

function codexRuntimeRulesBlock() {
  const rules = [];
  for (const path of permissionPathVariants(setupHelperPath)) {
    rules.push(codexPrefixRule({
      pattern: ["node", path, "--label", "codex"],
      justification: "Allow Spill Codex label handoff without repeated approval prompts.",
    }));
  }
  return [
    "# spill-token-metering:begin",
    "# Managed by Spill token metering setup. Keep narrow; do not replace with broad python3/node allow rules.",
    ...rules,
    "# spill-token-metering:end",
  ].join("\n");
}

function codexPrefixRule({ pattern, justification }) {
  const encodedPattern = pattern.map((item) => JSON.stringify(item)).join(", ");
  return [
    "prefix_rule(",
    `    pattern = [${encodedPattern}],`,
    '    decision = "allow",',
    `    justification = ${JSON.stringify(justification)},`,
    ")",
  ].join("\n");
}

async function configureAgentRuntimeSettings({ tool, target, permissionPrefix }) {
  if (!apply) {
    results.push({ tool, action: "would_configure_agent_runtime", path: target });
    return;
  }

  const config = await readJSONObject(target);
  const env = plainObject(config.env) ? config.env : {};
  env.SPILL_AI_TOOL = tool;
  env.SPILL_TOKEN_USAGE_AI_TOOL = tool;
  config.env = env;

  const permissions = plainObject(config.permissions) ? config.permissions : {};
  const allow = Array.isArray(permissions.allow)
    ? permissions.allow.filter(
        (item) => typeof item === "string" && !isStaleAgentRuntimePermissionEntry(item, permissionPrefix)
      )
    : [];
  const existing = new Set(allow);
  for (const entry of [
    ...agentRuntimePermissionEntries(tool, permissionPrefix),
    ...macosPlatformPermissionEntries(permissionPrefix),
  ]) {
    if (!existing.has(entry)) {
      allow.push(entry);
      existing.add(entry);
    }
  }
  permissions.allow = allow;
  config.permissions = permissions;

  await writeJSONObject(target, config);
  results.push({ tool, action: "configured_agent_runtime", path: target });

  if (apply && tool === "antigravity" && process.platform === "darwin") {
    try {
      await execPromise("launchctl kickstart -k gui/$(id -u)/com.trappist.agentcatd");
      results.push({ tool: "antigravity", action: "daemon_restarted" });
    } catch (err) {
      results.push({ tool: "antigravity", action: "daemon_restart_failed", reason: err.message });
    }
  }
}

function agentRuntimePermissionEntries(tool, permissionPrefix) {
  const entries = [];
  const commandForms = new Set();

  for (const path of permissionPathVariants(setupHelperPath)) {
    addPermissionCommandVariants(commandForms, `node ${path} --label ${tool}`);
  }

  // Add the spill-hook.py script itself
  const hookScriptPath = join(installRoot, tool === "claude" ? "claude-code" : tool, "spill-hook.py");
  const paths = [hookScriptPath];
  if (tool === "antigravity") {
    paths.push(join(homedir(), ".gemini", "spill-hook.py"));
  }

  for (const hookPath of paths) {
    for (const path of permissionPathVariants(hookPath)) {
      addPermissionCommandVariants(commandForms, `python3 ${path}`);
      addPermissionCommandVariants(commandForms, `SPILL_AI_TOOL=${tool} python3 ${path}`);
      addPermissionCommandVariants(commandForms, `SPILL_TOKEN_USAGE_AI_TOOL=${tool} python3 ${path}`);
    }
  }

  for (const command of commandForms) {
    entries.push(`${permissionPrefix}(${command})`);
  }
  return entries;
}

// Commands that are genuinely read-only but absent from Claude Code's built-in
// auto-allow list because it was written for Linux (md5sum, sha256sum) while
// macOS ships different names (md5, shasum). Without these entries every agent
// session on macOS prompts for permission on routine hash / version checks.
function macosPlatformPermissionEntries(permissionPrefix) {
  const missing = [
    "md5 *",       // macOS equivalent of md5sum — always read-only
    "shasum *",    // macOS equivalent of sha256sum/sha1sum — always read-only
    "sw_vers *",   // macOS version query — always read-only
  ];
  return missing.map((cmd) => `${permissionPrefix}(${cmd})`);
}

function isStaleAgentRuntimePermissionEntry(entry, permissionPrefix) {
  const prefix = `${permissionPrefix}(`;
  if (!entry.startsWith(prefix) || !entry.endsWith(")")) return false;
  const command = entry.slice(prefix.length, -1);
  return /^(?:SPILL_(?:AI_TOOL|TOKEN_USAGE_AI_TOOL)=[a-z]+ )?python3 scripts\/(?:workflow\.py|agent-preflight\.py|agent-finish-check\.py)(?::\*| \*)?$/.test(command);
}

function addPermissionCommandVariants(commandForms, command) {
  commandForms.add(command);
  commandForms.add(`${command}:*`);
  commandForms.add(`${command} *`);
}

function permissionPathVariants(path) {
  const variants = new Set([path, shellQuote(path), doubleQuote(path), escapePermissionPath(path)]);
  const homeRelative = homeRelativePath(path);
  if (homeRelative !== path) {
    variants.add(homeRelative);
    variants.add(escapePermissionPath(homeRelative));
  }
  for (const envPath of homeEnvironmentPathVariants(path)) {
    variants.add(envPath);
    variants.add(doubleQuote(envPath));
    variants.add(escapePermissionPath(envPath));
  }
  return [...variants];
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

async function writeManagedTextBlock({ path, begin, end, block }) {
  await mkdir(dirname(path), { recursive: true });
  const before = await exists(path) ? await readFile(path, "utf8") : "";
  const pattern = new RegExp(`${escapeRegExp(begin)}[\\s\\S]*?${escapeRegExp(end)}\\n?`, "m");
  const normalizedBlock = `${block}\n`;
  const after = pattern.test(before)
    ? before.replace(pattern, normalizedBlock)
    : `${before}${before && !before.endsWith("\n") ? "\n" : ""}${normalizedBlock}`;
  if (after === before) return;
  if (await exists(path)) {
    await copyFile(path, `${path}.spill-backup-${STAMP}`);
  }
  const temporary = `${path}.tmp-${process.pid}`;
  await writeFile(temporary, after, { mode: 0o600 });
  await rename(temporary, path);
}

async function writeRuntimeLabel({ tool, taskType, stage, labelFile, ttlMinutes, ifAbsent }) {
  const safeTool = safeToolLabel(tool);
  const safeTaskType = safeWorkflowSlug(taskType, "task_type");
  const safeStage = safeWorkflowSlug(stage, "stage");
  const ttl = safeTTLMinutes(ttlMinutes);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + ttl * 60 * 1000);
  const target = expandHome(labelFile ?? join(
    homedir(),
    "Library/Application Support/Spill/token-metering/label-context",
    `${safeTool}.json`,
  ));
  if (ifAbsent) {
    const existing = await readActiveRuntimeLabel(target, safeTool, now);
    if (existing) {
      return {
        tool: safeTool,
        task_type: existing.task_type,
        stage: existing.stage,
        label_file: target,
        expires_at: existing.expires_at,
        skipped: true,
      };
    }
  }

  const value = {
    ai_tool: safeTool,
    task_type: safeTaskType,
    stage: safeStage,
    updated_at: now.toISOString(),
    expires_at: expiresAt.toISOString(),
  };

  await mkdir(dirname(target), { recursive: true });
  const temporary = `${target}.tmp-${process.pid}`;
  await writeFile(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  await rename(temporary, target);

  return {
    tool: safeTool,
    task_type: safeTaskType,
    stage: safeStage,
    label_file: target,
    expires_at: value.expires_at,
    skipped: false,
  };
}

async function readActiveRuntimeLabel(path, expectedTool, now) {
  try {
    const data = JSON.parse(await readFile(path, "utf8"));
    if (!plainObject(data)) return null;
    if (data.ai_tool !== expectedTool) return null;
    if (!safeWorkflowSlugOrEmpty(data.task_type)) return null;
    if (!safeWorkflowSlugOrEmpty(data.stage)) return null;
    const expiry = typeof data.expires_at === "string"
      ? new Date(data.expires_at)
      : null;
    if (!expiry || Number.isNaN(expiry.getTime()) || expiry <= now) return null;
    return {
      task_type: data.task_type,
      stage: data.stage,
      expires_at: data.expires_at,
    };
  } catch {
    return null;
  }
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
    case "--if-absent":
      parsed.ifAbsent = true;
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
    case "--label":
      parsed.label = requiredValue(values, ++index, value);
      break;
    case "--task-type":
      parsed.taskType = requiredValue(values, ++index, value);
      break;
    case "--stage":
      parsed.stage = requiredValue(values, ++index, value);
      break;
    case "--label-file":
      parsed.labelFile = requiredValue(values, ++index, value);
      break;
    case "--ttl-minutes":
      parsed.ttlMinutes = requiredValue(values, ++index, value);
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
  --apply                 Copy adapters and merge known user-level hook config files in one pass.
  --force                 Install every included adapter even when it is not a default hook adapter or detected.
  --include LIST          Comma list. Default: codex,claude,antigravity. Optional: openai.
  --workflow-hook PATH    Also add the Antigravity/AGY workflow hook to this selected hooks.json.
  --source-root PATH      Adapter source root. Default: repo or bundled adapters directory.
  --install-dir PATH      Adapter install root. Default: ~/Library/Application Support/Spill/adapters.
  --label TOOL            Write a short-lived safe task/stage label for codex, claude, antigravity, or openai.
  --if-absent             With --label, keep an active same-tool label instead of overwriting it.
  --task-type SLUG        Safe task label for --label.
  --stage SLUG            Safe stage label for --label.
  --label-file PATH       Override the runtime label file path for --label.
  --ttl-minutes MINUTES   Runtime label expiry. Default: 30.
  --json                  Print JSON summary.

Default mode is a dry-run. A normal --apply run installs Codex,
Claude Code, and Antigravity/AGY metering together, even if the current
agent is only one of those tools. Codex is the OpenAI-backed agent
runtime hook. The OpenAI SDK adapter is optional and installs only when
included explicitly.
The helper also installs or refreshes itself at the default setup command path.
When Claude Code or Antigravity/AGY user settings exist, the helper sets
SPILL_AI_TOOL for that runtime and adds narrow allowlist entries for Spill label
handoff and installed Spill hook commands so routine metering setup does not
repeatedly ask for permission. Codex defaults to the codex tool label. Workflow
runner permissions are separate from the default Spill metering install.
The installer never reads prompts, transcripts, commands, logs, diffs, source
files, environment values, or secrets.
`);
}

function expandHome(path) {
  if (path === "~") return homedir();
  if (path.startsWith("~/")) return join(homedir(), path.slice(2));
  return path;
}

function homeRelativePath(path) {
  const home = homedir();
  if (path === home) return "~";
  if (path.startsWith(`${home}/`)) return `~/${path.slice(home.length + 1)}`;
  return path;
}

function homeEnvironmentPathVariants(path) {
  const home = homedir();
  if (!path.startsWith(`${home}/`)) return [];
  const suffix = path.slice(home.length + 1);
  return [`$HOME/${suffix}`, `\${HOME}/${suffix}`];
}

function escapePermissionPath(path) {
  return path.replaceAll(" ", "\\ ");
}

function doubleQuote(value) {
  return `"${value.replaceAll("\\", "\\\\").replaceAll('"', '\\"')}"`;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function plainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function safeToolLabel(value) {
  const normalized = String(value ?? "").toLowerCase();
  if (normalized === "agy") {
    return "antigravity";
  }
  if (["codex", "claude", "antigravity", "openai"].includes(normalized)) {
    return normalized;
  }
  throw new Error(`Invalid --label tool: ${value}`);
}

function safeWorkflowSlug(value, name) {
  if (typeof value !== "string" || !/^[a-z][a-z0-9_]{1,40}$/.test(value)) {
    throw new Error(`Invalid ${name}: ${value ?? ""}`);
  }
  return value;
}

function safeWorkflowSlugOrEmpty(value) {
  return typeof value === "string" && /^[a-z][a-z0-9_]{1,40}$/.test(value);
}

function safeTTLMinutes(value) {
  if (value === undefined) return 30;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 1 || parsed > 240) {
    throw new Error(`Invalid --ttl-minutes: ${value}`);
  }
  return parsed;
}

function shellQuote(value) {
  if (value.includes(" ") || value.includes("'") || value.includes('"') || value.includes("$") || value.includes("\\")) {
    return `'${value.replaceAll("'", "'\\''")}'`;
  }
  return value;
}
