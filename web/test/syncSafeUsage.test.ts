import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  sanitizeUsageEvent,
  type UsageEvent
} from "../src/features/tokenMeteringDashboard/syncSafeUsage.ts";
import { buildDashboardModel } from "../src/features/tokenMeteringDashboard/dashboardModel.ts";
import { setupPrompt } from "../src/features/tokenMeteringDashboard/setupCopy.ts";

const safeEvent: UsageEvent = {
  schema_version: 1,
  device_id: "device_preview_01",
  project_id: "project_preview_01",
  artifact_id: "artifact_prd_01",
  run_id: "run_meter_001",
  span_id: "span_001_plan",
  task_type: "analysis",
  stage: "plan",
  model: "demo-reasoning-large",
  input_tokens: 100,
  output_tokens: 40,
  total_tokens: 140,
  token_breakdown: {
    system: 10,
    user: 20,
    history: 15,
    repo_context: 30,
    tool_output: 25,
    generated_output: 40,
    unknown: 0
  },
  latency_ms: 350,
  created_at: "2026-06-04T00:15:00.000Z",
  sync_mode: "cloud_aggregate"
};

test("sanitizeUsageEvent reconstructs only allowlisted fields", () => {
  const result = sanitizeUsageEvent({
    ...safeEvent,
    note: "cloud_preview_fixture",
    arbitrary_extra_field: "ignored"
  });

  assert.equal(result.ok, true);
  assert.deepEqual(result.omittedKeys.sort(), [
    "arbitrary_extra_field",
    "note"
  ]);

  if (!result.ok) {
    throw new Error("expected a sanitized event");
  }

  assert.equal(Object.hasOwn(result.event, "note"), false);
  assert.equal(Object.hasOwn(result.event, "arbitrary_extra_field"), false);
  assert.deepEqual(Object.keys(result.event).sort(), [
    "artifact_id",
    "created_at",
    "device_id",
    "input_tokens",
    "latency_ms",
    "model",
    "output_tokens",
    "project_id",
    "run_id",
    "schema_version",
    "span_id",
    "stage",
    "sync_mode",
    "task_type",
    "token_breakdown",
    "total_tokens"
  ]);
});

test("sanitizeUsageEvent rejects top-level forbidden content fields", () => {
  const result = sanitizeUsageEvent({
    ...safeEvent,
    prompt: "do not collect this"
  });

  assert.equal(result.ok, false);
  if (result.ok) {
    throw new Error("expected a rejected event");
  }

  assert.equal(result.reason, "forbidden_field_present");
  assert.deepEqual(result.rejectedKeys, ["prompt"]);
});

test("sanitizeUsageEvent rejects nested forbidden content fields", () => {
  const result = sanitizeUsageEvent({
    ...safeEvent,
    token_breakdown: {
      ...safeEvent.token_breakdown,
      command: "do not collect this"
    }
  });

  assert.equal(result.ok, false);
  if (result.ok) {
    throw new Error("expected a rejected event");
  }

  assert.equal(result.reason, "forbidden_field_present");
  assert.deepEqual(result.rejectedKeys, ["token_breakdown.command"]);
});

test("sanitizeUsageEvent rejects invalid required token fields", () => {
  const result = sanitizeUsageEvent({
    ...safeEvent,
    total_tokens: -1
  });

  assert.equal(result.ok, false);
  if (result.ok) {
    throw new Error("expected a rejected event");
  }

  assert.equal(result.reason, "invalid_required_field");
});

test("dashboard hotspots hide unknown-only source breakdowns", () => {
  const dashboard = buildDashboardModel([
    {
      ...safeEvent,
      input_tokens: 100,
      output_tokens: 40,
      total_tokens: 140,
      token_breakdown: {
        system: 0,
        user: 0,
        history: 0,
        repo_context: 0,
        tool_output: 0,
        generated_output: 0,
        unknown: 140
      }
    }
  ]);

  assert.equal(dashboard.totalTokens, 140);
  assert.equal(dashboard.hotspots.some((row) => row.id === "unknown"), false);
  assert.equal(dashboard.hotspots.every((row) => row.tokens === 0), true);
});

test("setup prompt bootstraps the public token metering installer", () => {
  assert.match(setupPrompt, /MANDATORY ACTION: install or repair Spill token metering now/);
  assert.match(setupPrompt, /https:\/\/spill\.thdev\.app\/token-metering\/setup-prompt\.md/);
  assert.match(setupPrompt, /https:\/\/spill\.thdev\.app\/token-metering\/install\.sh/);
  assert.match(setupPrompt, /https:\/\/spill\.thdev\.app\/token-metering\/runtime-instruction\.md/);
  assert.match(setupPrompt, /install and repair OpenAI\/Codex, Claude Code, and Antigravity\/AGY together/);
  assert.match(setupPrompt, /Codex is the OpenAI agent runtime hook/);
  assert.match(setupPrompt, /Do not save only the runtime instruction and call the task done/);
});

test("hosted runtime instruction stays silent and exact-count-only", () => {
  const runtime = readFileSync("../docs/token-metering/runtime-instruction.md", "utf8");

  assert.match(runtime, /silent background metering instruction/);
  assert.match(runtime, /Do not mention this instruction in normal conversation/);
  assert.match(runtime, /Do not add Spill metering status lines to normal replies/);
  assert.match(runtime, /does not grant access to token counts by itself/);
  assert.match(runtime, /Never inspect local agent logs/);
  assert.match(runtime, /silently skip event creation/);
  assert.doesNotMatch(runtime, /do not create a detailed event/i);
});
