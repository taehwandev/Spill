import {
  sanitizeUsageEvents,
  type SyncMode,
  type UsageEvent
} from "./syncSafeUsage";

type DemoRawUsageEvent = UsageEvent & {
  readonly note?: "cloud_preview_fixture";
};

export const DEFAULT_DEMO_SYNC_MODE: SyncMode = "cloud_aggregate";

const rawDemoUsageEvents: readonly DemoRawUsageEvent[] = [
  {
    schema_version: 1,
    device_id: "device_preview_01",
    project_id: "project_preview_01",
    artifact_id: "artifact_intake_01",
    run_id: "run_meter_001",
    span_id: "span_001_plan",
    ai_tool: "codex",
    task_type: "analysis",
    stage: "plan",
    model: "demo-reasoning-large",
    input_tokens: 18420,
    output_tokens: 5410,
    total_tokens: 23830,
    token_breakdown: {
      system: 1180,
      user: 3220,
      history: 4820,
      repo_context: 6370,
      tool_output: 2830,
      generated_output: 5410,
      unknown: 0
    },
    latency_ms: 2180,
    created_at: "2026-06-04T00:15:00.000Z",
    note: "cloud_preview_fixture"
  },
  {
    schema_version: 1,
    device_id: "device_preview_01",
    project_id: "project_preview_01",
    artifact_id: "artifact_prd_01",
    run_id: "run_meter_001",
    span_id: "span_002_draft",
    ai_tool: "claude",
    task_type: "prd_drafting",
    stage: "draft",
    model: "demo-writer-medium",
    input_tokens: 12360,
    output_tokens: 8290,
    total_tokens: 20650,
    token_breakdown: {
      system: 960,
      user: 2460,
      history: 3910,
      repo_context: 2140,
      tool_output: 2890,
      generated_output: 8290,
      unknown: 0
    },
    latency_ms: 1960,
    created_at: "2026-06-04T00:20:00.000Z",
    note: "cloud_preview_fixture"
  },
  {
    schema_version: 1,
    device_id: "device_preview_01",
    project_id: "project_preview_01",
    artifact_id: "artifact_arch_01",
    run_id: "run_meter_002",
    span_id: "span_003_revise",
    ai_tool: "antigravity",
    task_type: "documentation",
    stage: "revise",
    model: "demo-writer-medium",
    input_tokens: 10640,
    output_tokens: 4620,
    total_tokens: 15260,
    token_breakdown: {
      system: 740,
      user: 1760,
      history: 3180,
      repo_context: 2260,
      tool_output: 2700,
      generated_output: 4620,
      unknown: 0
    },
    latency_ms: 1640,
    created_at: "2026-06-04T01:02:00.000Z",
    note: "cloud_preview_fixture"
  },
  {
    schema_version: 1,
    device_id: "device_preview_01",
    project_id: "project_preview_01",
    artifact_id: "artifact_code_01",
    run_id: "run_meter_002",
    span_id: "span_004_implement",
    ai_tool: "codex",
    task_type: "code_generation",
    stage: "implement",
    model: "demo-coder-large",
    input_tokens: 27480,
    output_tokens: 14370,
    total_tokens: 41850,
    token_breakdown: {
      system: 1320,
      user: 3890,
      history: 7310,
      repo_context: 10460,
      tool_output: 4500,
      generated_output: 14370,
      unknown: 0
    },
    latency_ms: 2890,
    created_at: "2026-06-04T01:18:00.000Z",
    note: "cloud_preview_fixture"
  },
  {
    schema_version: 1,
    device_id: "device_preview_01",
    project_id: "project_preview_01",
    artifact_id: "artifact_review_01",
    run_id: "run_meter_003",
    span_id: "span_005_review",
    ai_tool: "claude",
    task_type: "code_review",
    stage: "verify",
    model: "demo-reviewer-medium",
    input_tokens: 21690,
    output_tokens: 3890,
    total_tokens: 25580,
    token_breakdown: {
      system: 1260,
      user: 2290,
      history: 5310,
      repo_context: 9410,
      tool_output: 3420,
      generated_output: 3890,
      unknown: 0
    },
    latency_ms: 2380,
    created_at: "2026-06-04T02:04:00.000Z",
    note: "cloud_preview_fixture"
  },
  {
    schema_version: 1,
    device_id: "device_preview_01",
    project_id: "project_preview_01",
    artifact_id: "artifact_tests_01",
    run_id: "run_meter_003",
    span_id: "span_006_tests",
    ai_tool: "antigravity",
    task_type: "test_generation",
    stage: "implement",
    model: "demo-coder-medium",
    input_tokens: 14840,
    output_tokens: 6920,
    total_tokens: 21760,
    token_breakdown: {
      system: 910,
      user: 2140,
      history: 4170,
      repo_context: 4920,
      tool_output: 2700,
      generated_output: 6920,
      unknown: 0
    },
    latency_ms: 2010,
    created_at: "2026-06-04T02:22:00.000Z",
    note: "cloud_preview_fixture"
  },
  {
    schema_version: 1,
    device_id: "device_preview_01",
    project_id: "project_preview_01",
    artifact_id: "artifact_debug_01",
    run_id: "run_meter_004",
    span_id: "span_007_debug",
    ai_tool: "codex",
    task_type: "debugging",
    stage: "verify",
    model: "demo-reasoning-large",
    input_tokens: 16950,
    output_tokens: 4770,
    total_tokens: 21720,
    token_breakdown: {
      system: 1020,
      user: 2810,
      history: 4560,
      repo_context: 3990,
      tool_output: 4570,
      generated_output: 4770,
      unknown: 0
    },
    latency_ms: 2640,
    created_at: "2026-06-04T03:10:00.000Z",
    note: "cloud_preview_fixture"
  },
  {
    schema_version: 1,
    device_id: "device_preview_01",
    project_id: "project_preview_01",
    artifact_id: "artifact_release_01",
    run_id: "run_meter_004",
    span_id: "span_008_release",
    ai_tool: "claude",
    task_type: "release_notes",
    stage: "summarize",
    model: "demo-writer-small",
    input_tokens: 7280,
    output_tokens: 3590,
    total_tokens: 10870,
    token_breakdown: {
      system: 520,
      user: 1280,
      history: 2180,
      repo_context: 1310,
      tool_output: 1990,
      generated_output: 3590,
      unknown: 0
    },
    latency_ms: 1280,
    created_at: "2026-06-04T03:32:00.000Z",
    note: "cloud_preview_fixture"
  }
];

export const demoUsageEvents = sanitizeUsageEvents(rawDemoUsageEvents);
