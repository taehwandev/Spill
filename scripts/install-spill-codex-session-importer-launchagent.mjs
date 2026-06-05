#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { mkdir, unlink, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";

const label = "app.spill.codex-session-importer";
const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const importerPath = join(repoRoot, "scripts", "spill-codex-session-importer.mjs");
const plistPath = join(homedir(), "Library", "LaunchAgents", `${label}.plist`);
const logDir = join(homedir(), "Library", "Logs", "Spill");
const action = process.argv[2] ?? "install";
const allowPolling = process.argv.includes("--allow-polling");

if (action === "install") {
  if (!allowPolling) {
    process.stderr.write([
      "Polling LaunchAgent install is disabled by default.",
      "Use a runtime Stop/final-span hook to run spill-codex-session-importer.mjs once per turn.",
      "Pass --allow-polling only if you explicitly want the legacy 5s watcher.",
      "",
    ].join("\n"));
    process.exit(1);
  }
  await install();
} else if (action === "uninstall") {
  await uninstall();
} else if (action === "status") {
  status();
} else {
  process.stderr.write(`Usage: ${process.argv[1]} [install --allow-polling|uninstall|status]\n`);
  process.exit(1);
}

async function install() {
  await mkdir(dirname(plistPath), { recursive: true });
  await mkdir(logDir, { recursive: true });

  run(process.execPath, [
    importerPath,
    "--since-hours",
    "1",
    "--mark-existing",
    "--json",
    "--strict",
  ]);

  await writeFile(plistPath, plist(), { encoding: "utf8", mode: 0o644 });
  bootout({ allowFailure: true });
  run("launchctl", ["bootstrap", domain(), plistPath]);
  run("launchctl", ["kickstart", "-k", `${domain()}/${label}`]);
  status();
}

async function uninstall() {
  bootout({ allowFailure: true });
  await unlink(plistPath).catch(() => {});
}

function status() {
  run("launchctl", ["print", `${domain()}/${label}`], { allowFailure: true });
}

function bootout({ allowFailure }) {
  run("launchctl", ["bootout", domain(), plistPath], { allowFailure });
}

function domain() {
  const uid = typeof process.getuid === "function" ? process.getuid() : "";
  return `gui/${uid}`;
}

function plist() {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${escapeXML(process.execPath)}</string>
    <string>${escapeXML(importerPath)}</string>
    <string>--watch</string>
    <string>--since-hours</string>
    <string>1</string>
    <string>--json</string>
    <string>--transport</string>
    <string>file</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${escapeXML(repoRoot)}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${escapeXML(join(logDir, "codex-session-importer.log"))}</string>
  <key>StandardErrorPath</key>
  <string>${escapeXML(join(logDir, "codex-session-importer.err.log"))}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>SPILL_TOKEN_USAGE_TRANSPORT</key>
    <string>file</string>
  </dict>
</dict>
</plist>
`;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    stdio: "inherit",
  });
  if (result.status !== 0 && !options.allowFailure) {
    process.exit(result.status ?? 1);
  }
}

function escapeXML(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}
