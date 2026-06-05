#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const root = process.cwd();
const agentDocsPath = path.join(root, ".agents/agent-docs.json");
const agentPlaybookRoot =
  process.env.AGENTPLAYBOOK_HOME ??
  path.join(os.homedir(), "Documents/KeyFlowVault/AgentPlaybook");

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exitCode = 1;
}

function ok(message) {
  console.log(`OK: ${message}`);
}

function exists(relativePath) {
  return fs.existsSync(path.join(root, relativePath));
}

if (!fs.existsSync(agentDocsPath)) {
  fail("Missing .agents/agent-docs.json");
  process.exit();
}

const agentDocs = JSON.parse(fs.readFileSync(agentDocsPath, "utf8"));

for (const doc of agentDocs.requiredDocs ?? []) {
  if (exists(doc)) {
    ok(`found ${doc}`);
  } else {
    fail(`missing ${doc}`);
  }
}

if (!fs.existsSync(agentPlaybookRoot)) {
  ok(`AgentPlaybook not installed at ${agentPlaybookRoot}; skipping shared docs check`);
} else {
  for (const doc of agentDocs.requiredAgentPlaybookDocs ?? []) {
    const fullPath = path.join(agentPlaybookRoot, doc);
    if (fs.existsSync(fullPath)) {
      ok(`found AgentPlaybook ${doc}`);
    } else {
      fail(`missing AgentPlaybook ${doc} at ${agentPlaybookRoot}`);
    }
  }
}

const requiredRunFiles = [
  "00-intake.md",
  "01-prd.md",
  "02-ard.md",
  "03-task-breakdown.yml",
  "04-agent-briefs.md",
  "05-verification.md",
  "06-closeout.md"
];

const runsDir = path.join(root, ".agents/runs");
if (fs.existsSync(runsDir)) {
  for (const entry of fs.readdirSync(runsDir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;

    const runPath = path.join(runsDir, entry.name);
    for (const file of requiredRunFiles) {
      const fullPath = path.join(runPath, file);
      if (fs.existsSync(fullPath)) {
        ok(`run ${entry.name} has ${file}`);
      } else {
        fail(`run ${entry.name} missing ${file}`);
      }
    }
  }
}

const hardRuleFiles = [
  ".agents/specs/prd.md",
  ".agents/specs/ard.md"
];

for (const file of hardRuleFiles) {
  if (!exists(file)) continue;
  const text = fs.readFileSync(path.join(root, file), "utf8");
  if (!text.toLowerCase().includes("spacer")) {
    fail(`${file} should mention spacer constraints`);
  }
  if (!text.toLowerCase().includes("private api")) {
    fail(`${file} should mention private API constraints`);
  }
}

if (!process.exitCode) {
  console.log("Workflow docs verified.");
}
