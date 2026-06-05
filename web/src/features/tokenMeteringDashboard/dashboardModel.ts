import {
  FORBIDDEN_SYNC_FIELD_LABELS,
  TASK_TYPES,
  TOKEN_SOURCES,
  hasOnlySyncSafeKeys,
  type SyncMode,
  type TaskType,
  type TokenSource,
  type UsageEvent
} from "./syncSafeUsage.ts";

export const taskTypeLabels = {
  uncategorized: "Uncategorized",
  analysis: "Analysis",
  prd_drafting: "PRD drafting",
  code_generation: "Code generation",
  code_review: "Code review",
  test_generation: "Test generation",
  debugging: "Debugging",
  documentation: "Documentation",
  release_notes: "Release notes"
} satisfies Record<TaskType, string>;

export const tokenSourceLabels = {
  system: "System",
  user: "User",
  history: "History",
  repo_context: "Repo context",
  tool_output: "Tool output",
  generated_output: "Generated output",
  unknown: "Unknown aggregate"
} satisfies Record<TokenSource, string>;

export const syncModeContent = {
  local_only: {
    label: "Local only",
    status: "No cloud transfer",
    summary: "Detailed categorization stays on this computer.",
    cloudPayload: "Nothing is sent."
  },
  cloud_aggregate: {
    label: "Cloud aggregate",
    status: "Future opt-in",
    summary: "Account sync would include totals, timestamps, models, and latency.",
    cloudPayload: "Numeric aggregate fields only."
  },
  cloud_detailed: {
    label: "Cloud detailed",
    status: "Separate future opt-in",
    summary:
      "Detailed cloud charts would use numeric counts and enum labels only.",
    cloudPayload: "Numeric counts plus enum labels."
  }
} satisfies Record<
  SyncMode,
  {
    label: string;
    status: string;
    summary: string;
    cloudPayload: string;
  }
>;

export type Kpi = {
  label: string;
  value: string;
  detail: string;
};

export type BreakdownRow = {
  id: TaskType;
  label: string;
  tokens: number;
  percentage: number;
};

export type HotspotRow = {
  id: TokenSource;
  label: string;
  tokens: number;
  percentage: number;
};

export type SessionTraceRun = {
  runId: string;
  totalTokens: number;
  latencyMs: number;
  steps: {
    spanId: string;
    taskType: string;
    stage: string;
    model: string;
    totalTokens: number;
    latencyMs: number;
    createdAt: string;
  }[];
};

export type PrivacyAudit = {
  eventsPrepared: number;
  emittedFieldsSafe: boolean;
  allowedFieldCount: number;
  forbiddenLabels: readonly string[];
};

export type DashboardModel = {
  kpis: Kpi[];
  totalTokens: number;
  taskBreakdown: BreakdownRow[];
  hotspots: HotspotRow[];
  sessionTrace: SessionTraceRun[];
  privacyAudit: PrivacyAudit;
};

const demoPricingPerMillion = {
  input: 2.5,
  output: 10
};

export function buildDashboardModel(events: readonly UsageEvent[]): DashboardModel {
  const totals = events.reduce(
    (acc, event) => {
      acc.input += event.input_tokens;
      acc.output += event.output_tokens;
      acc.total += event.total_tokens;
      acc.latency += event.latency_ms;
      return acc;
    },
    { input: 0, output: 0, total: 0, latency: 0 }
  );

  const averageLatency =
    events.length > 0 ? Math.round(totals.latency / events.length) : 0;
  const estimatedCost =
    (totals.input / 1_000_000) * demoPricingPerMillion.input +
    (totals.output / 1_000_000) * demoPricingPerMillion.output;

  return {
    kpis: [
      {
        label: "Total tokens",
        value: formatTokens(totals.total),
        detail: `${events.length} preview spans`
      },
      {
        label: "Input tokens",
        value: formatTokens(totals.input),
        detail: `${percentOf(totals.input, totals.total)}% of total`
      },
      {
        label: "Output tokens",
        value: formatTokens(totals.output),
        detail: `${percentOf(totals.output, totals.total)}% of total`
      },
      {
        label: "Estimated cost",
        value: formatCurrency(estimatedCost),
        detail: "Estimate only"
      },
      {
        label: "Avg latency",
        value: formatLatency(averageLatency),
        detail: "Per run/span step"
      }
    ],
    totalTokens: totals.total,
    taskBreakdown: buildTaskBreakdown(events, totals.total),
    hotspots: buildHotspots(events, totals.total),
    sessionTrace: buildSessionTrace(events),
    privacyAudit: {
      eventsPrepared: events.length,
      emittedFieldsSafe: events.every((event) => hasOnlySyncSafeKeys(event)),
      allowedFieldCount: 16,
      forbiddenLabels: FORBIDDEN_SYNC_FIELD_LABELS
    }
  };
}

export function formatTokens(value: number): string {
  return new Intl.NumberFormat("en-US").format(value);
}

export function formatLatency(value: number): string {
  return `${new Intl.NumberFormat("en-US").format(value)} ms`;
}

function buildTaskBreakdown(
  events: readonly UsageEvent[],
  totalTokens: number
): BreakdownRow[] {
  return TASK_TYPES.map((taskType) => {
    const tokens = events
      .filter((event) => event.task_type === taskType)
      .reduce((sum, event) => sum + event.total_tokens, 0);

    return {
      id: taskType,
      label: taskTypeLabels[taskType],
      tokens,
      percentage: percentOf(tokens, totalTokens)
    };
  });
}

function buildHotspots(
  events: readonly UsageEvent[],
  totalTokens: number
): HotspotRow[] {
  return TOKEN_SOURCES.filter((source) => source !== "unknown").map((source) => {
    const tokens = events.reduce(
      (sum, event) => sum + event.token_breakdown[source],
      0
    );

    return {
      id: source,
      label: tokenSourceLabels[source],
      tokens,
      percentage: percentOf(tokens, totalTokens)
    };
  }).sort((left, right) => right.tokens - left.tokens);
}

function buildSessionTrace(events: readonly UsageEvent[]): SessionTraceRun[] {
  const runs = new Map<string, UsageEvent[]>();
  for (const event of events) {
    const current = runs.get(event.run_id) ?? [];
    current.push(event);
    runs.set(event.run_id, current);
  }

  return Array.from(runs.entries()).map(([runId, runEvents]) => {
    const sortedEvents = [...runEvents].sort((left, right) =>
      left.created_at.localeCompare(right.created_at)
    );

    return {
      runId,
      totalTokens: sortedEvents.reduce(
        (sum, event) => sum + event.total_tokens,
        0
      ),
      latencyMs: sortedEvents.reduce((sum, event) => sum + event.latency_ms, 0),
      steps: sortedEvents.map((event) => ({
        spanId: event.span_id,
        taskType: taskTypeLabels[event.task_type],
        stage: event.stage,
        model: event.model,
        totalTokens: event.total_tokens,
        latencyMs: event.latency_ms,
        createdAt: event.created_at
      }))
    };
  });
}

function percentOf(value: number, total: number): number {
  return total === 0 ? 0 : Math.round((value / total) * 100);
}

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 2
  }).format(value);
}
