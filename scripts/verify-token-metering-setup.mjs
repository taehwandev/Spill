#!/usr/bin/env node
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtemp, mkdir, readFile, readdir, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const helper = process.env.SPILL_SETUP_TEST_HELPER ?? join(root, "scripts/spill-token-metering-setup.mjs");
const canonical = await readFile(join(root, "docs/token-metering/runtime-instruction.md"), "utf8");
const begin = "<!-- spill-token-metering-instruction:begin -->";
const end = "<!-- spill-token-metering-instruction:end -->";
const oldBridge = `${begin}\nold bridge\n${end}\n`;

async function fixture(t) {
  const home = await mkdtemp(join(tmpdir(), "spill-setup-regression-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  for (const tool of [".codex", ".claude", ".antigravity"]) await mkdir(join(home, tool));
  return home;
}

function install(home, extra = [], apply = true) {
  return execFileSync(process.execPath, [
    helper, "--home", home, ...(apply ? ["--apply"] : []), "--include", "codex,claude,antigravity",
    "--source-root", join(root, "Sources/Spill/Resources/adapters"),
    "--runtime-instruction-source", join(root, "docs/token-metering/runtime-instruction.md"),
    "--json", ...extra,
  ], { env: { ...process.env, HOME: home }, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
}

const instructionPath = (home) => join(home, ".codex/AGENTS.md");
const count = (text, marker) => text.split(marker).length - 1;

test("collapses duplicate bridges without removing intervening personal rules", async (t) => {
  const home = await fixture(t);
  const before = `# Personal rules\nkeep-before\n${oldBridge}keep-between\n${oldBridge}keep-after\n`;
  await writeFile(instructionPath(home), before);
  install(home);
  const after = await readFile(instructionPath(home), "utf8");
  assert.equal(count(after, begin), 1);
  for (const rule of ["keep-before", "keep-between", "keep-after"]) assert(after.includes(rule));
  const backups = (await readdir(join(home, ".codex"))).filter((name) => name.startsWith("AGENTS.md.spill-backup-"));
  assert.equal(backups.length, 1);
  assert.equal(await readFile(join(home, ".codex", backups[0]), "utf8"), before);
  assert.equal((await stat(instructionPath(home))).mode & 0o777, 0o600);
});

test("reinstall leaves the instruction bytes, mtime and backup count unchanged", async (t) => {
  const home = await fixture(t);
  install(home);
  const before = await readFile(instructionPath(home), "utf8");
  const modified = (await stat(instructionPath(home))).mtimeMs;
  install(home);
  assert.equal(await readFile(instructionPath(home), "utf8"), before);
  assert.equal((await stat(instructionPath(home))).mtimeMs, modified);
  assert.equal((await readdir(join(home, ".codex"))).filter((name) => name.startsWith("AGENTS.md.spill-backup-")).length, 0);
});

test("consolidates complete CRLF markers with surrounding whitespace", async (t) => {
  const home = await fixture(t);
  const spaced = `  ${begin} \r\nold bridge\r\n\t${end} \r\n`;
  await writeFile(instructionPath(home), `${spaced}keep-personal\r\n${spaced}`);
  install(home);
  const after = await readFile(instructionPath(home), "utf8");
  assert.equal(count(after, begin), 1);
  assert(after.includes("keep-personal"));
});

test("consolidates managed permission rules and keeps personal rules", async (t) => {
  const home = await fixture(t);
  const rules = join(home, ".codex/rules/default.rules");
  await mkdir(dirname(rules));
  const old = "# spill-token-metering:begin\nold-permission\n# spill-token-metering:end\n";
  await writeFile(rules, `keep-rule-before\n${old}keep-rule-between\n${old}keep-rule-after\n`);
  install(home);
  const after = await readFile(rules, "utf8");
  assert.equal(count(after, "# spill-token-metering:begin"), 1);
  for (const rule of ["keep-rule-before", "keep-rule-between", "keep-rule-after"]) assert(after.includes(rule));
  assert(!after.includes('prefix_rule(["node"],'));
});

test("replaces exact inline copies while preserving opt-in display and workflow rules", async (t) => {
  const home = await fixture(t);
  const personal = "## Optional Local Display Names Enabled\nkeep-display-option\n<!-- tao-runtime-bridge:start -->\nkeep-tao\n<!-- tao-runtime-bridge:end -->\n";
  await writeFile(instructionPath(home), `# Personal\nkeep-personal\n${canonical}\n${canonical}\n${personal}`);
  install(home);
  const after = await readFile(instructionPath(home), "utf8");
  assert.equal(count(after, "# Spill Token Metering Runtime Instruction"), 0);
  assert.equal(count(after, begin), 1);
  assert(after.includes(personal));
  assert(after.includes("keep-personal"));
  assert(after.includes("reuse its guidance in this session unless it changes"));
  assert(after.includes("per-turn fallback label handoff enabled"));
});

test("recognizes inline copies with CRLF line endings", async (t) => {
  const home = await fixture(t);
  await writeFile(instructionPath(home), canonical.replace(/\n/g, "\r\n"));
  install(home);
  assert.equal(count(await readFile(instructionPath(home), "utf8"), "# Spill Token Metering Runtime Instruction"), 0);
});

test("does not remove a customized inline instruction", async (t) => {
  const home = await fixture(t);
  const custom = `${canonical.trim()}\nCustom personal exception must survive.\n`;
  await writeFile(instructionPath(home), custom);
  install(home);
  assert((await readFile(instructionPath(home), "utf8")).startsWith(custom));
});

test("metering-only repair preserves every existing instruction layer", async (t) => {
  const home = await fixture(t);
  const before = `${canonical}\n${oldBridge}${oldBridge}`;
  await writeFile(instructionPath(home), before);
  install(home, ["--metering-only"]);
  assert.equal(await readFile(instructionPath(home), "utf8"), before);
  await assert.rejects(stat(join(home, ".spill/runtime-instruction.md")), { code: "ENOENT" });
});

test("dry-run creates no adapters, bridge, backup or canonical instruction", async (t) => {
  const home = await fixture(t);
  const before = `${canonical}\n${oldBridge}${oldBridge}`;
  await writeFile(instructionPath(home), before);
  install(home, [], false);
  assert.equal(await readFile(instructionPath(home), "utf8"), before);
  await assert.rejects(stat(join(home, ".spill/runtime-instruction.md")), { code: "ENOENT" });
  assert.deepEqual(await readdir(join(home, ".codex")), ["AGENTS.md"]);
});

for (const [name, invalid] of [
  ["unclosed", `${begin}\nkeep-malformed\n`],
  ["nested", `${begin}\nkeep-malformed\n${oldBridge}${end}\n`],
  ["unmatched", `${end}\nkeep-malformed\n`],
]) {
  test(`preserves ${name} blocks and fails with a repairable error`, async (t) => {
    const home = await fixture(t);
    await writeFile(instructionPath(home), invalid);
    assert.throws(() => install(home), (error) => /Spill managed text/.test(String(error.stderr)));
    assert.equal(await readFile(instructionPath(home), "utf8"), invalid);
    assert.equal((await readdir(join(home, ".codex"))).filter((file) => file.startsWith("AGENTS.md.spill-backup-")).length, 0);
  });
}

test("respects Codex override and Claude import while preserving unrelated hooks", async (t) => {
  const home = await fixture(t);
  await writeFile(instructionPath(home), "keep-codex-base\n");
  await writeFile(join(home, ".codex/AGENTS.override.md"), `${oldBridge}keep-override\n${oldBridge}`);
  const unrelatedHook = { matcher: "", hooks: [{ type: "command", command: "fixture-unrelated-hook" }] };
  await writeFile(join(home, ".claude/settings.json"), JSON.stringify({ hooks: { Stop: [unrelatedHook] } }));
  await writeFile(join(home, ".claude/CLAUDE.md"), `keep-language\n${oldBridge}keep-tao\n${oldBridge}`);
  install(home);
  install(home);
  assert.equal(await readFile(instructionPath(home), "utf8"), "keep-codex-base\n");
  const override = await readFile(join(home, ".codex/AGENTS.override.md"), "utf8");
  assert.equal(count(override, begin), 1);
  assert(override.includes("keep-override"));
  const claude = await readFile(join(home, ".claude/CLAUDE.md"), "utf8");
  assert.equal(count(claude, begin), 1);
  assert(claude.includes(`@${join(home, ".spill/runtime-instruction.md")}`));
  assert(claude.includes("keep-language") && claude.includes("keep-tao"));
  const settings = JSON.parse(await readFile(join(home, ".claude/settings.json"), "utf8"));
  assert.deepEqual(settings.hooks.Stop.find((entry) => entry.hooks[0].command === "fixture-unrelated-hook"), unrelatedHook);
  assert.equal(settings.hooks.Stop.filter((entry) => entry.hooks.some((hook) => hook.command.includes("spill-hook.py"))).length, 1);
});
