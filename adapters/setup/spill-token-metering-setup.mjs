#!/usr/bin/env node

import { access, appendFile, chmod, copyFile, mkdir, readFile, rename, stat, writeFile, unlink } from "node:fs/promises";
import { constants } from "node:fs";
import { createHmac, randomBytes } from "node:crypto";
import { execFile } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";
import { promisify } from "node:util";

const STAMP = new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);
const execFileAsync = promisify(execFile);
const args = parseArgs(process.argv.slice(2));
const apply = args.apply === true;
const force = args.force === true;
const json = args.json === true;
const meteringOnly = args.meteringOnly === true;
const installRoot = expandHome(args.installDir ?? join(homedir(), "Library/Application Support/Spill/adapters"));
const setupHelperPath = join(installRoot, "setup", "spill-token-metering-setup.mjs");
const statsHelperPath = join(installRoot, "setup", "spill-token-metering-stats.mjs");
const installedRuntimeInstructionPath = join(installRoot, "setup", "runtime-instruction.md");
const sharedRuntimeInstructionPath = expandHome(
  args.sharedInstruction ?? join(homedir(), ".spill", "runtime-instruction.md")
);
const defaultAdapters = "codex,claude,antigravity";
const managedRuntimeRulesBegin = "# spill-token-metering:begin";
const managedRuntimeRulesEnd = "# spill-token-metering:end";
const managedRuntimeInstructionBegin = "<!-- spill-token-metering-instruction:begin -->";
const managedRuntimeInstructionEnd = "<!-- spill-token-metering-instruction:end -->";
const alwaysInstallAdapters = new Set(defaultAdapters.split(","));
const include = new Set((args.include ?? defaultAdapters).split(",").map((item) => item.trim()).filter(Boolean));

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
const runtimeInstructionSource = await resolveRuntimeInstructionSource(args.runtimeInstructionSource);

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
    source: null,
    destination: null,
    executable: false,
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
await installSetupHelper(runtimeInstructionSource);
if (!meteringOnly) {
  await installSharedRuntimeInstruction(runtimeInstructionSource);
}
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

await configureRuntimeLabelDefaults({ installsInstructionBridges: !meteringOnly });

if (json) {
  process.stdout.write(`${JSON.stringify({ apply, metering_only: meteringOnly, source_root: sourceRoot, install_root: installRoot, results }, null, 2)}\n`);
} else {
  for (const result of results) {
    const suffix = result.reason ? ` (${result.reason})` : "";
    process.stdout.write(`${result.action}: ${result.tool}${suffix}\n`);
  }
  if (!apply) {
    process.stdout.write("dry-run: pass --apply to install Codex, Claude Code, and Antigravity/AGY metering in one pass.\n");
  }
}

async function installSetupHelper(runtimeInstructionSource) {
  if (!apply) {
    results.push({ tool: "setup", action: "would_install", path: setupHelperPath });
    results.push({ tool: "stats", action: "would_install", path: statsHelperPath });
    results.push({ tool: "runtime_instruction_source", action: "would_install", path: installedRuntimeInstructionPath });
    return;
  }

  const source = fileURLToPath(import.meta.url);
  await mkdir(dirname(setupHelperPath), { recursive: true });
  if (resolve(source) !== resolve(setupHelperPath)) {
    await copyFile(source, setupHelperPath);
  }
  await chmod(setupHelperPath, 0o755);
  results.push({ tool: "setup", action: "installed", path: setupHelperPath });

  const statsSource = await resolveStatsHelperSource(source);
  await copyFile(statsSource, statsHelperPath);
  await chmod(statsHelperPath, 0o755);
  results.push({ tool: "stats", action: "installed", path: statsHelperPath });

  await installPrivateFile(runtimeInstructionSource, installedRuntimeInstructionPath);
  results.push({ tool: "runtime_instruction_source", action: "installed", path: installedRuntimeInstructionPath });
}

async function installSharedRuntimeInstruction(runtimeInstructionSource) {
  if (!apply) {
    results.push({ tool: "runtime_instruction", action: "would_install", path: sharedRuntimeInstructionPath });
    return;
  }

  await installPrivateFile(runtimeInstructionSource, sharedRuntimeInstructionPath);
  results.push({ tool: "runtime_instruction", action: "installed", path: sharedRuntimeInstructionPath });
}

async function installPrivateFile(source, destination) {
  await mkdir(dirname(destination), { recursive: true, mode: 0o700 });
  if (resolve(source) === resolve(destination)) {
    await chmod(destination, 0o600);
    return;
  }

  const temporary = `${destination}.tmp-${process.pid}`;
  await copyFile(source, temporary);
  await chmod(temporary, 0o600);
  await rename(temporary, destination);
}

async function installAdapter(adapter) {
  if (!adapter.source || !adapter.destination) {
    results.push({ tool: adapter.id, action: "active_importer_only", reason: "no_runtime_hook" });
    return;
  }

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
  await removeLegacyClaudeScannerLaunchAgent();
}

async function configureAntigravity(scriptPath) {
  const targets = [
    join(homedir(), ".gemini", "config", "hooks.json"),
    join(homedir(), ".gemini", "hooks.json"),
    join(homedir(), ".gemini", "antigravity-cli", "hooks.json")
  ];
  for (const target of targets) {
    await removeAgyHookFile(target, "antigravity");
  }

  if (apply) {
    await removeFileIfExists(join(homedir(), ".gemini", "spill-hook.py"), "antigravity");
    await removeFileIfExists(join(homedir(), ".gemini", "spill-hook-wrapper.py"), "antigravity");
  } else {
    results.push({ tool: "antigravity", action: "would_remove_legacy_hook_files", path: join(homedir(), ".gemini") });
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

async function removeAgyHookFile(target, tool) {
  if (!apply) {
    results.push({ tool, action: "would_remove_hook", path: target });
    return;
  }

  if (!await exists(target)) {
    results.push({ tool, action: "skip_remove_hook", reason: "missing_config", path: target });
    return;
  }

  const config = await readJSONObject(target);
  const match = /spill-hook(?:-wrapper)?\.py/;
  const hookName = "spill-metering";

  if (plainObject(config[hookName])) {
    const namedSpec = config[hookName];
    if (Array.isArray(namedSpec.PostInvocation)) {
      const list = removeMatchingHookGroups(namedSpec.PostInvocation, match);
      if (list.length > 0) {
        namedSpec.PostInvocation = list;
      } else {
        delete namedSpec.PostInvocation;
      }
    }
    if (Object.keys(namedSpec).length === 0) {
      delete config[hookName];
    }
  }

  if (Array.isArray(config.PostInvocation)) {
    const list = removeMatchingHookGroups(config.PostInvocation, match);
    if (list.length > 0) {
      config.PostInvocation = list;
    } else {
      delete config.PostInvocation;
    }
  }

  await writeJSONObject(target, config);
  results.push({ tool, action: "removed_hook", path: target });
}

function removeMatchingHookGroups(groups, match) {
  return groups.map(group => {
    if (!plainObject(group) || !Array.isArray(group.hooks)) return group;
    const remaining = group.hooks.filter(hook => !plainObject(hook) || typeof hook.command !== "string" || !match.test(hook.command));
    return { ...group, hooks: remaining };
  }).filter(group => !plainObject(group) || !Array.isArray(group.hooks) || group.hooks.length > 0);
}

async function removeFileIfExists(path, tool) {
  try {
    await unlink(path);
    results.push({ tool, action: "removed_legacy_hook_file", path });
  } catch (err) {
    if (err && err.code === "ENOENT") {
      results.push({ tool, action: "skip_remove_legacy_hook_file", reason: "missing_file", path });
      return;
    }
    results.push({ tool, action: "remove_legacy_hook_file_failed", reason: err.message, path });
  }
}

async function removeLegacyClaudeScannerLaunchAgent() {
  const plist = join(homedir(), "Library", "LaunchAgents", "net.thdev.spill.claude-scanner.plist");
  if (!apply) {
    results.push({ tool: "claude", action: "would_remove_legacy_scanner_launchagent", path: plist });
    return;
  }

  if (!await exists(plist)) {
    results.push({ tool: "claude", action: "skip_remove_legacy_scanner_launchagent", reason: "missing_file", path: plist });
    return;
  }

  await unloadLegacyLaunchAgent(plist, "claude");
  try {
    await unlink(plist);
    results.push({ tool: "claude", action: "removed_legacy_scanner_launchagent", path: plist });
  } catch (err) {
    results.push({ tool: "claude", action: "remove_legacy_scanner_launchagent_failed", reason: err.message, path: plist });
  }
}

async function unloadLegacyLaunchAgent(plist, tool) {
  if (typeof process.getuid !== "function") {
    results.push({ tool, action: "skip_unload_legacy_scanner_launchagent", reason: "uid_unavailable", path: plist });
    return;
  }

  try {
    await execFileAsync("launchctl", ["bootout", `gui/${process.getuid()}`, plist], { timeout: 5000 });
    results.push({ tool, action: "unloaded_legacy_scanner_launchagent", path: plist });
  } catch (err) {
    results.push({
      tool,
      action: "skip_unload_legacy_scanner_launchagent",
      reason: err.code || err.message,
      path: plist,
    });
  }
}

async function configureRuntimeLabelDefaults({ installsInstructionBridges }) {
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
  if (!installsInstructionBridges) {
    return;
  }
  if (include.has("codex")) {
    await configureRuntimeInstructionBridge({
      tool: "codex",
      target: await codexRuntimeInstructionTarget(),
      block: pointerRuntimeInstructionBlock("Codex"),
    });
  }
  if (include.has("claude")) {
    await configureRuntimeInstructionBridge({
      tool: "claude",
      target: join(homedir(), ".claude", "CLAUDE.md"),
      block: importedRuntimeInstructionBlock(),
    });
  }
  if (include.has("antigravity")) {
    await configureRuntimeInstructionBridge({
      tool: "antigravity",
      target: join(homedir(), ".antigravity", "AGENTS.md"),
      block: pointerRuntimeInstructionBlock("Antigravity/AGY"),
    });
  }

  async function codexRuntimeInstructionTarget() {
    const override = join(homedir(), ".codex", "AGENTS.override.md");
    return await exists(override) ? override : join(homedir(), ".codex", "AGENTS.md");
  }

  async function configureRuntimeInstructionBridge({ tool, target, block }) {
    if (!apply) {
      results.push({ tool, action: "would_configure_instruction_bridge", path: target });
      return;
    }

    await writeManagedTextBlock({
      path: target,
      begin: managedRuntimeInstructionBegin,
      end: managedRuntimeInstructionEnd,
      block,
    });
    results.push({ tool, action: "configured_instruction_bridge", path: target });
  }

  function pointerRuntimeInstructionBlock(runtimeName) {
    return [
      managedRuntimeInstructionBegin,
      "## Spill Token Metering",
      `Before each user-visible task, read and follow \`${sharedRuntimeInstructionPath}\` when it exists.`,
      `This ${runtimeName} bridge only points to Spill's shared instruction; do not copy the full instruction into this file.`,
      managedRuntimeInstructionEnd,
    ].join("\n");
  }

  function importedRuntimeInstructionBlock() {
    return [
      managedRuntimeInstructionBegin,
      `@${sharedRuntimeInstructionPath}`,
      managedRuntimeInstructionEnd,
    ].join("\n");
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
    begin: managedRuntimeRulesBegin,
    end: managedRuntimeRulesEnd,
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
  for (const path of permissionPathVariants(statsHelperPath)) {
    rules.push(codexPrefixRule({
      pattern: ["node", path, "--self"],
      justification: "Allow read-only Spill local usage status checks when the user asks.",
    }));
    rules.push(codexPrefixRule({
      pattern: ["node", path, "--tool", "codex"],
      justification: "Allow read-only Spill Codex usage status checks when the user asks.",
    }));
  }
  return [
    managedRuntimeRulesBegin,
    "# Managed by Spill token metering setup. Keep narrow; do not replace with broad python3/node allow rules.",
    ...rules,
    managedRuntimeRulesEnd,
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
}

function agentRuntimePermissionEntries(tool, permissionPrefix) {
  const entries = [];
  const commandForms = new Set();

  for (const path of permissionPathVariants(setupHelperPath)) {
    addPermissionCommandVariants(commandForms, `node ${path} --label ${tool}`);
  }
  for (const path of permissionPathVariants(statsHelperPath)) {
    addPermissionCommandVariants(commandForms, `node ${path} --self`);
    addPermissionCommandVariants(commandForms, `node ${path} --tool ${tool}`);
  }

  const hookPaths = tool === "claude"
    ? [join(installRoot, "claude-code", "spill-hook.py")]
    : [];

  for (const hookPath of hookPaths) {
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
  const pattern = managedTextBlockPattern(begin, end);
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

function managedTextBlockPattern(begin, end) {
  const rulesBlock = begin === managedRuntimeRulesBegin && end === managedRuntimeRulesEnd;
  const instructionBlock = begin === managedRuntimeInstructionBegin && end === managedRuntimeInstructionEnd;
  if (!rulesBlock && !instructionBlock) {
    throw new Error("Invalid managed text block markers");
  }

  return new RegExp(`${escapeRegExp(begin)}[\\s\\S]*?${escapeRegExp(end)}\\n?`, "m");
}

async function writeRuntimeLabel({ tool, taskType, stage, labelFile, ttlMinutes, ifAbsent }) {
  const safeTool = safeToolLabel(tool);
  const safeTaskType = safeWorkflowSlug(taskType, "task_type");
  const safeStage = safeWorkflowSlug(stage, "stage");
  const projectID = await resolveLocalProjectID();
  const ttl = safeTTLMinutes(ttlMinutes);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + ttl * 60 * 1000);
  const target = expandHome(labelFile ?? join(
    homedir(),
    "Library/Application Support/Spill/token-metering/label-context",
    `${safeTool}.json`,
  ));
  let activeLabel = null;
  if (ifAbsent) {
    activeLabel = await readActiveRuntimeLabel(target, safeTool, now);
    if (activeLabel?.project_id) {
      return {
        tool: safeTool,
        task_type: activeLabel.task_type,
        stage: activeLabel.stage,
        project_id: activeLabel.project_id,
        label_file: target,
        expires_at: activeLabel.expires_at,
        skipped: true,
      };
    }
  }
  const nextTaskType = activeLabel?.task_type ?? safeTaskType;
  const nextStage = activeLabel?.stage ?? safeStage;
  const nextExpiresAt = activeLabel?.expires_at ?? expiresAt.toISOString();

  const value = {
    ai_tool: safeTool,
    task_type: nextTaskType,
    stage: nextStage,
    project_id: projectID,
    updated_at: now.toISOString(),
    expires_at: nextExpiresAt,
  };

  await mkdir(dirname(target), { recursive: true });
  const temporary = `${target}.tmp-${process.pid}`;
  await writeFile(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  await rename(temporary, target);

  // Append to timeline so the Active Importer can match each event's timestamp
  // to the correct label range without relying on a single overwritten file.
  const timelineFile = target.replace(/\.json$/, "-timeline.jsonl");
  const timelineLine = `${JSON.stringify({
    ai_tool: safeTool,
    task_type: nextTaskType,
    stage: nextStage,
    project_id: projectID,
    updated_at: value.updated_at,
    expires_at: value.expires_at,
  })}\n`;
  try {
    await appendFile(timelineFile, timelineLine, { mode: 0o600 });
  } catch {
    // Non-fatal: single JSON file is still written above.
  }

  return {
    tool: safeTool,
    task_type: nextTaskType,
    stage: nextStage,
    project_id: projectID,
    label_file: target,
    expires_at: value.expires_at,
    skipped: Boolean(activeLabel),
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
      project_id: optionalOpaqueID(data.project_id),
      expires_at: data.expires_at,
    };
  } catch {
    return null;
  }
}

async function resolveLocalProjectID() {
  const root = await detectProjectIdentityRoot(process.cwd());
  const salt = await readOrCreateProjectIDSalt();
  const bytes = createHmac("sha256", salt)
    .update(normalizeProjectIdentityRoot(root))
    .digest()
    .subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  return `project_${Buffer.from(bytes).toString("hex")}`;
}

async function detectProjectIdentityRoot(start) {
  const original = resolve(start);
  let current = original;
  const markers = [
    ".git",
    ".agents",
    "AGENTS.md",
    "Package.swift",
    "package.json",
    "Cargo.toml",
    "go.mod",
    "pyproject.toml",
  ];

  while (true) {
    for (const marker of markers) {
      if (await exists(join(current, marker))) return current;
    }
    const parent = dirname(current);
    if (parent === current) return original;
    current = parent;
  }
}

function normalizeProjectIdentityRoot(root) {
  return resolve(root)
    .replace(/\\/g, "/")
    .replace(/\/+$/g, "")
    .normalize("NFC");
}

async function readOrCreateProjectIDSalt() {
  const saltFile = join(
    homedir(),
    "Library/Application Support/Spill/token-metering/project-identity-salt",
  );
  try {
    const existing = (await readFile(saltFile, "utf8")).trim();
    if (/^[a-f0-9]{64}$/i.test(existing)) return existing;
  } catch {
    // Missing salt is expected on first use.
  }

  await mkdir(dirname(saltFile), { recursive: true, mode: 0o700 });
  const value = randomBytes(32).toString("hex");
  const temporary = `${saltFile}.tmp-${process.pid}`;
  await writeFile(temporary, `${value}\n`, { mode: 0o600, flag: "wx" });
  await rename(temporary, saltFile);
  return value;
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

async function resolveStatsHelperSource(setupSource) {
  const candidates = [
    join(dirname(setupSource), "spill-token-metering-stats.mjs"),
    join(sourceRoot, "setup", "spill-token-metering-stats.mjs"),
  ];
  for (const candidate of candidates) {
    if (await exists(candidate)) return candidate;
  }
  throw new Error("Missing Spill stats helper source: spill-token-metering-stats.mjs");
}

async function resolveRuntimeInstructionSource(option) {
  if (option) {
    const candidate = resolve(expandHome(option));
    if (await exists(candidate)) return candidate;
    throw new Error(`Missing Spill runtime instruction source: ${candidate}`);
  }

  const setupSource = fileURLToPath(import.meta.url);
  const setupDirectory = dirname(setupSource);
  const candidates = [
    join(setupDirectory, "runtime-instruction.md"),
    join(sourceRoot, "setup", "runtime-instruction.md"),
    join(setupDirectory, "..", "docs", "token-metering", "runtime-instruction.md"),
    join(setupDirectory, "..", "..", "docs", "token-metering", "runtime-instruction.md"),
  ];
  for (const candidate of candidates) {
    if (await exists(candidate)) return resolve(candidate);
  }
  throw new Error("Missing Spill runtime instruction source: runtime-instruction.md");
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
    case "--metering-only":
      parsed.meteringOnly = true;
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
    case "--runtime-instruction-source":
      parsed.runtimeInstructionSource = requiredValue(values, ++index, value);
      break;
    case "--shared-instruction":
      parsed.sharedInstruction = requiredValue(values, ++index, value);
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
  --apply                 Copy adapters, configure Codex/Claude hooks, remove legacy Claude scanner, and remove managed AGY hooks in one pass.
  --metering-only         Install exact token collection without adding shared runtime instructions or instruction bridges.
  --force                 Install every included adapter even when it is not a default adapter or detected.
  --include LIST          Comma list. Default: codex,claude,antigravity. Optional: openai.
  --source-root PATH      Adapter source root. Default: repo or bundled adapters directory.
  --install-dir PATH      Adapter install root. Default: ~/Library/Application Support/Spill/adapters.
  --runtime-instruction-source PATH
                          Shared runtime instruction source. Default: bundled or repo runtime-instruction.md.
  --shared-instruction PATH
                          Installed shared instruction. Default: ~/.spill/runtime-instruction.md.
  --label TOOL            Write a short-lived safe task/stage label for codex, claude, antigravity, or openai.
  --if-absent             With --label, keep an active same-tool label instead of overwriting it.
  --task-type SLUG        Safe task label for --label.
  --stage SLUG            Safe stage label for --label.
  --label-file PATH       Override the runtime label file path for --label.
  --ttl-minutes MINUTES   Runtime label expiry. Default: 30.
  --json                  Print JSON summary.

Default mode is a dry-run. A normal --apply run installs Codex/Claude Code
hook adapters and configures Antigravity/AGY active importer cleanup together,
even if the current agent is only one of those tools. Codex is the
OpenAI-backed agent runtime hook. Antigravity/AGY has no Spill runtime hook.
The OpenAI SDK adapter is optional and installs only when included explicitly.
The helper also installs or refreshes itself and the read-only local usage stats
helper at the default setup command path. It writes one shared agent instruction
to ~/.spill/runtime-instruction.md and adds only a small managed discovery bridge
to Codex, Claude Code, and Antigravity/AGY user instruction files.
When Claude Code or Antigravity/AGY user settings exist, the helper sets
SPILL_AI_TOOL for that runtime and adds narrow allowlist entries for Spill label
handoff, explicit user-requested Spill local usage status checks, and
Codex/Claude hook commands so routine metering setup does not repeatedly ask for
permission. Codex defaults to the codex tool label.
Workflow runner permissions are separate from the default Spill metering
install.
Installed local importers may read known Codex/Claude JSONL transcript or
session files and Antigravity/AGY metadata records on this Mac only to extract
exact token counts, timestamps, model ids, and opaque ids. They never store or
upload prompts, responses, commands, file paths, transcript text, logs, diffs,
source files, environment values, or secrets.
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

function optionalOpaqueID(value) {
  return typeof value === "string" && /^[A-Za-z0-9_-]{6,64}$/.test(value)
    ? value
    : "";
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
  return `'${String(value).replaceAll("'", "'\\''")}'`;
}
