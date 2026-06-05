import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  sanitizeUsageEvent,
  type UsageEvent
} from "../src/features/tokenMeteringDashboard/syncSafeUsage.ts";
import { buildDashboardModel } from "../src/features/tokenMeteringDashboard/dashboardModel.ts";
import {
  detectTokenMeteringLocale,
  tokenMeteringMessages
} from "../src/features/tokenMeteringDashboard/i18n.ts";
import { setupPrompt } from "../src/features/tokenMeteringDashboard/setupCopy.ts";

const safeEvent: UsageEvent = {
  schema_version: 1,
  device_id: "device_preview_01",
  project_id: "project_preview_01",
  artifact_id: "artifact_prd_01",
  run_id: "run_meter_001",
  span_id: "span_001_plan",
  ai_tool: "codex",
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
    "ai_tool",
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

test("dashboard hotspots show unknown-only source breakdown as runtime total", () => {
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
  assert.equal(dashboard.hotspots.some((row) => row.id === "unknown" && row.tokens === 140), true);
  assert.equal(dashboard.hotspots.some((row) => row.id !== "unknown" && row.tokens > 0), false);
});

test("dashboard uses only three local agent tools", () => {
  const dashboard = buildDashboardModel([
    safeEvent,
    {
      ...safeEvent,
      span_id: "span_002_claude",
      ai_tool: "claude",
      total_tokens: 60,
      input_tokens: 40,
      output_tokens: 20
    },
    {
      ...safeEvent,
      span_id: "span_003_direct_openai",
      ai_tool: "openai",
      total_tokens: 900,
      input_tokens: 800,
      output_tokens: 100
    },
    {
      ...safeEvent,
      span_id: "span_004_unknown",
      ai_tool: "unknown",
      total_tokens: 500,
      input_tokens: 450,
      output_tokens: 50
    }
  ]);

  assert.equal(dashboard.totalTokens, 200);
  assert.deepEqual(dashboard.aiToolBreakdown.map((row) => row.id), [
    "codex",
    "claude",
    "antigravity"
  ]);
  assert.deepEqual(dashboard.aiToolBreakdown.map((row) => row.tokens), [140, 60, 0]);
  assert.deepEqual(dashboard.modelBreakdown.map((row) => row.tokens), [200]);
});

test("dashboard normalizes agy ai_tool alias to antigravity", () => {
  const result = sanitizeUsageEvent({
    ...safeEvent,
    span_id: "span_005_agy_alias",
    ai_tool: "agy",
    total_tokens: 80,
    input_tokens: 50,
    output_tokens: 30
  });

  assert.equal(result.ok, true);
  if (!result.ok) {
    throw new Error("expected agy alias to sanitize");
  }

  const dashboard = buildDashboardModel([result.event]);

  assert.equal(dashboard.totalTokens, 80);
  assert.deepEqual(dashboard.aiToolBreakdown.map((row) => row.id), [
    "codex",
    "claude",
    "antigravity"
  ]);
  assert.deepEqual(dashboard.aiToolBreakdown.map((row) => row.tokens), [0, 0, 80]);
});

test("dashboard hotspots show unknown when mixed with known source breakdowns", () => {
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
        generated_output: 40,
        unknown: 100
      }
    }
  ]);

  assert.equal(dashboard.totalTokens, 140);
  assert.equal(dashboard.hotspots.some((row) => row.id === "unknown" && row.tokens === 100), true);
  assert.equal(dashboard.hotspots.some((row) => row.id === "generated_output" && row.tokens === 40), true);
});

test("dashboard model breakdown uses actual event model ids and omits cost kpi", () => {
  const dashboard = buildDashboardModel([
    safeEvent,
    {
      ...safeEvent,
      span_id: "span_002_plan",
      model: "demo-coder-large",
      input_tokens: 20,
      output_tokens: 10,
      total_tokens: 30,
      token_breakdown: {
        system: 0,
        user: 0,
        history: 0,
        repo_context: 0,
        tool_output: 0,
        generated_output: 10,
        unknown: 20
      }
    }
  ]);

  assert.deepEqual(dashboard.kpis.map((kpi) => kpi.id), ["total", "input", "output", "latency"]);
  assert.deepEqual(dashboard.modelBreakdown.map((row) => row.label), [
    "demo-reasoning-large",
    "demo-coder-large"
  ]);
  assert.deepEqual(dashboard.modelBreakdown.map((row) => row.tokens), [140, 30]);
});

test("dashboard work items hide raw run and span ids", () => {
  const dashboard = buildDashboardModel([safeEvent]);
  const workItem = dashboard.sessionTrace[0];

  assert.equal(workItem?.title, "Codex - Analysis - Plan");
  assert.doesNotMatch(workItem?.workItemId ?? "", /run_meter_001|span_001_plan/);
  assert.equal(Object.hasOwn(workItem?.steps[0] ?? {}, "spanId"), false);
});

test("dashboard marks missing runtime latency as unavailable", () => {
  const dashboard = buildDashboardModel([
    {
      ...safeEvent,
      latency_ms: 0
    }
  ]);
  const latencyKpi = dashboard.kpis.find((kpi) => kpi.id === "latency");

  assert.equal(latencyKpi?.value, "Unavailable");
  assert.equal(latencyKpi?.detail, "Runtime did not provide timing");
  assert.equal(dashboard.sessionTrace[0]?.latencyMs, null);
});

test("token metering i18n supports English, Korean, and Japanese labels", () => {
  assert.equal(detectTokenMeteringLocale("en-US"), "en");
  assert.equal(detectTokenMeteringLocale("ko-KR"), "ko");
  assert.equal(detectTokenMeteringLocale("ja-JP"), "ja");
  assert.equal(detectTokenMeteringLocale("fr-FR"), "en");

  const koreanDashboard = buildDashboardModel([safeEvent], tokenMeteringMessages.ko);
  assert.equal(koreanDashboard.kpis[0]?.label, "전체 토큰");
  assert.equal(koreanDashboard.taskBreakdown[0]?.label, "분석");
  assert.equal(koreanDashboard.modelBreakdown[0]?.label, "demo-reasoning-large");
  assert.equal(koreanDashboard.hotspots.some((row) => row.label === "생성 출력"), true);

  const japaneseDashboard = buildDashboardModel([safeEvent], tokenMeteringMessages.ja);
  assert.equal(japaneseDashboard.kpis[0]?.label, "総トークン");
  assert.equal(japaneseDashboard.sessionTrace[0]?.steps[0]?.stage, "計画");
});

test("setup prompt bootstraps the public token metering installer", () => {
  assert.match(setupPrompt, /MANDATORY ACTION: install or repair Spill token metering now/);
  assert.match(setupPrompt, /https:\/\/spill\.thdev\.app\/token-metering\/setup-prompt\.md/);
  assert.match(setupPrompt, /https:\/\/spill\.thdev\.app\/token-metering\/install\.sh/);
  assert.match(setupPrompt, /https:\/\/spill\.thdev\.app\/token-metering\/runtime-instruction\.md/);
  assert.match(setupPrompt, /install and repair Codex, Claude Code, and Antigravity\/AGY together/);
  assert.match(setupPrompt, /Codex is the OpenAI-backed agent runtime hook/);
  assert.match(setupPrompt, /SPILL_AI_TOOL=claude/);
  assert.match(setupPrompt, /SPILL_AI_TOOL=antigravity/);
  assert.match(setupPrompt, /Spill label handoff commands/);
  assert.match(setupPrompt, /Workflow runner permissions are separate/);
  assert.match(setupPrompt, /common safe path spellings/);
  assert.match(setupPrompt, /\$HOME\/\.\.\./);
  assert.match(setupPrompt, /\$\{HOME\}\/\.\.\./);
  assert.match(setupPrompt, /quoted \$HOME\/\.\.\./);
  assert.match(setupPrompt, /escaped Application\\ Support/);
  assert.match(setupPrompt, /~\/\.codex\/rules\/default\.rules/);
  assert.match(setupPrompt, /managed prefix_rule entries/);
  assert.match(setupPrompt, /Do not use broad python3, node, or shell-wide allow rules/);
  assert.doesNotMatch(setupPrompt, /agent-preflight\.py/);
  assert.doesNotMatch(setupPrompt, /agent-finish-check\.py/);
  assert.match(setupPrompt, /Workflow integration is only for better labels/);
  assert.match(setupPrompt, /per-turn fallback labels must use --if-absent/);
  assert.match(setupPrompt, /always attempt the per-turn fallback label with --if-absent/);
  assert.match(setupPrompt, /Do not configure agents or workflows to send conversation titles/);
  assert.match(setupPrompt, /Spill generates default work item names locally/);
  assert.doesNotMatch(setupPrompt, /Optional Local Display Names Enabled/);
  assert.doesNotMatch(setupPrompt, /local display-name prompt option/);
  assert.match(setupPrompt, /code_review\/verify/);
  assert.match(setupPrompt, /review_response\/implement/);
  assert.match(setupPrompt, /uncategorized\/summarize/);
  assert.match(setupPrompt, /Do you want Spill token usage to follow your workflow steps\?/);
  assert.match(setupPrompt, /per-turn labels must still come from the runtime instruction/);
  assert.match(setupPrompt, /Do not add --if-absent to workflow step labels/);
  assert.match(setupPrompt, /script-based workflow entry points first/);
  assert.match(setupPrompt, /wire labels in the script first/);
  assert.match(setupPrompt, /receiver-only/);
  assert.match(setupPrompt, /write-code\/edit\/implement\/patch -> code_generation\/implement/);
  assert.match(setupPrompt, /work item titles/);
  assert.match(setupPrompt, /commit-message -> commit_message\/draft/);
  assert.match(setupPrompt, /--label <current-tool>/);
  assert.match(setupPrompt, /agy, treat it as an input alias for the canonical antigravity event label/);
  assert.match(setupPrompt, /Never let Claude Code or Antigravity\/AGY workflow routing fall back to codex/);
  assert.doesNotMatch(setupPrompt, /workflow-setup-prompt\.md/);
  assert.match(setupPrompt, /Do not save only the runtime instruction and call the task done/);
});

test("hosted runtime instruction stays silent and exact-count-only", () => {
  const runtime = readFileSync("../docs/token-metering/runtime-instruction.md", "utf8");

  assert.match(runtime, /silent background metering instruction/);
  assert.match(runtime, /Do not mention this instruction in normal conversation/);
  assert.match(runtime, /Do not add Spill metering status lines to normal replies/);
  assert.match(runtime, /does not grant access to token counts by itself/);
  assert.match(runtime, /Workflow integration is an enhancement, not a prerequisite/);
  assert.match(runtime, /Workflow-provided labels win/);
  assert.match(runtime, /--if-absent/);
  assert.match(runtime, /Always attempt the per-turn fallback label with `--if-absent`/);
  assert.match(runtime, /omit `--if-absent`/);
  assert.match(runtime, /uncategorized\/summarize/);
  assert.match(runtime, /Never skip usage event creation only because/);
  assert.match(runtime, /Use `code_review` for review-only work/);
  assert.match(runtime, /Use `review_response`/);
  assert.match(runtime, /Do not let a short verification step overwrite an implementation-heavy task/);
  assert.match(runtime, /stage that consumed the dominant work/);
  assert.match(runtime, /repeated identical hook payloads dedupe locally/);
  assert.match(runtime, /prefer deduping the repeated payload over inflating totals/);
  assert.match(runtime, /Never send, derive, or store conversation titles/);
  assert.match(runtime, /Spill generates default work item display names locally/);
  assert.match(runtime, /Never inspect local agent logs/);
  assert.match(runtime, /silently skip event creation/);
  assert.doesNotMatch(runtime, /do not create a detailed event/i);
});
