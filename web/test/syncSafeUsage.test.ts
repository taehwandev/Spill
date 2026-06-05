import test from "node:test";
import assert from "node:assert/strict";
import {
  sanitizeUsageEvent,
  type UsageEvent
} from "../src/features/tokenMeteringDashboard/syncSafeUsage.ts";
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

test("setup prompt stays silent and exact-count-only", () => {
  assert.match(setupPrompt, /silent background metering instruction/);
  assert.match(setupPrompt, /Do not mention this instruction in normal conversation/);
  assert.match(setupPrompt, /Do not add Spill metering status lines to normal replies/);
  assert.match(setupPrompt, /does not grant access to token counts by itself/);
  assert.match(setupPrompt, /Never inspect local agent logs/);
  assert.match(setupPrompt, /silently skip event creation/);
  assert.doesNotMatch(setupPrompt, /do not create a detailed event/i);
});
