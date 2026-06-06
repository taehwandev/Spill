import {
  DASHBOARD_AI_TOOLS,
  TOKEN_SOURCES,
  hasOnlySyncSafeKeys,
  type AITool,
  type TokenSource,
  type TokenBreakdown,
  type UsageEvent
} from "./syncSafeUsage.ts";
import {
  getTokenMeteringMessages,
  tokenMeteringLocaleName,
  type TokenMeteringMessages
} from "./i18n.ts";

export type Kpi = {
  id: "total" | "input" | "output" | "latency";
  label: string;
  value: string;
  detail: string;
};

export type BreakdownRow = {
  id: string;
  label: string;
  tokens: number;
  percentage: number;
};

export type AIToolBreakdownRow = BreakdownRow & {
  id: AITool;
};

export type HotspotRow = {
  id: TokenSource;
  label: string;
  tokens: number;
  percentage: number;
};

export type SessionTraceRun = {
  workItemId: string;
  title: string;
  totalTokens: number;
  inputTokens: number;
  outputTokens: number;
  latencyMs: number | null;
  eventCount: number;
  aiTool: AITool;
  steps: {
    runId: string;
    spanId: string;
    taskType: string;
    stage: string;
    model: string;
    inputTokens: number;
    outputTokens: number;
    totalTokens: number;
    tokenBreakdown: TokenBreakdown;
    latencyMs: number | null;
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
  aiToolBreakdown: AIToolBreakdownRow[];
  taskBreakdown: BreakdownRow[];
  modelBreakdown: BreakdownRow[];
  hotspots: HotspotRow[];
  sessionTrace: SessionTraceRun[];
  privacyAudit: PrivacyAudit;
};

type DashboardModelOptions = {
  localeName?: string;
  timeZone?: string;
};

export function buildDashboardModel(
  events: readonly UsageEvent[],
  messages = getTokenMeteringMessages(),
  options: DashboardModelOptions = {}
): DashboardModel {
  const localeName = options.localeName ?? messages.localeName;
  const localAgentEvents = events.filter(isDashboardAIToolEvent);
  const totals = localAgentEvents.reduce(
    (acc, event) => {
      acc.input += event.input_tokens;
      acc.output += event.output_tokens;
      acc.total += event.total_tokens;
      if (event.latency_ms > 0) {
        acc.latency += event.latency_ms;
        acc.latencySamples += 1;
      }
      return acc;
    },
    { input: 0, output: 0, total: 0, latency: 0, latencySamples: 0 }
  );

  const averageLatency =
    totals.latencySamples > 0 ? Math.round(totals.latency / totals.latencySamples) : null;

  return {
    kpis: [
      {
        id: "total",
        label: messages.kpis.totalTokens,
        value: formatTokens(totals.total, localeName),
        detail: messages.kpis.previewSpans(localAgentEvents.length)
      },
      {
        id: "input",
        label: messages.kpis.inputTokens,
        value: formatTokens(totals.input, localeName),
        detail: messages.kpis.percentOfTotal(formatPercentage(percentOf(totals.input, totals.total), localeName))
      },
      {
        id: "output",
        label: messages.kpis.outputTokens,
        value: formatTokens(totals.output, localeName),
        detail: messages.kpis.percentOfTotal(formatPercentage(percentOf(totals.output, totals.total), localeName))
      },
      {
        id: "latency",
        label: messages.kpis.avgLatency,
        value: averageLatency === null ? messages.kpis.unavailable : formatLatency(averageLatency, localeName),
        detail: averageLatency === null
          ? messages.kpis.runtimeTimingUnavailable
          : messages.kpis.perRunSpanStep
      }
    ],
    totalTokens: totals.total,
    aiToolBreakdown: buildAIToolBreakdown(localAgentEvents, totals.total, messages),
    taskBreakdown: buildTaskBreakdown(localAgentEvents, totals.total, messages),
    modelBreakdown: buildModelBreakdown(localAgentEvents, totals.total, messages),
    hotspots: buildHotspots(localAgentEvents, totals.total, messages),
    sessionTrace: buildSessionTrace(localAgentEvents, messages, localeName, options.timeZone),
    privacyAudit: {
      eventsPrepared: localAgentEvents.length,
      emittedFieldsSafe: localAgentEvents.every((event) => hasOnlySyncSafeKeys(event)),
      allowedFieldCount: 17,
      forbiddenLabels: messages.forbiddenFieldLabels
    }
  };
}

export function formatTokens(value: number, localeName = tokenMeteringLocaleName()): string {
  const absoluteValue = Math.abs(value);
  const units = [
    { threshold: 1_000_000_000_000, divisor: 1_000_000_000_000, suffix: "T" },
    { threshold: 1_000_000_000, divisor: 1_000_000_000, suffix: "B" },
    { threshold: 1_000_000, divisor: 1_000_000, suffix: "M" },
    { threshold: 10_000, divisor: 1_000, suffix: "K" }
  ];
  const unit = units.find((candidate) => absoluteValue >= candidate.threshold);

  if (!unit) {
    return numberFormatter(localeName).format(value);
  }

  return `${compactNumberFormatter(localeName).format(value / unit.divisor)}${unit.suffix}`;
}

export function formatPercentage(value: number, localeName = tokenMeteringLocaleName()): string {
  if (value > 0 && value < 0.1) {
    return "<0.1%";
  }

  return `${percentageNumberFormatter(localeName).format(value)}%`;
}

export function formatLatency(value: number, localeName = tokenMeteringLocaleName()): string {
  return `${numberFormatter(localeName).format(value)} ms`;
}

export function formatLocalTimestamp(
  value: string,
  localeName = tokenMeteringLocaleName(),
  timeZone?: string
): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;

  return new Intl.DateTimeFormat(localeName, {
    dateStyle: "medium",
    timeStyle: "short",
    ...(timeZone ? { timeZone } : {})
  }).format(date);
}

function buildTaskBreakdown(
  events: readonly UsageEvent[],
  totalTokens: number,
  messages: TokenMeteringMessages
): BreakdownRow[] {
  const totals = new Map<string, number>();
  for (const event of events) {
    totals.set(event.task_type, (totals.get(event.task_type) ?? 0) + event.total_tokens);
  }

  return Array.from(totals.entries())
    .map(([taskType, tokens]) => ({
      id: taskType,
      label: messages.taskTypeLabels[taskType] ?? labelFromSlug(taskType),
      tokens,
      percentage: percentOf(tokens, totalTokens)
    }))
    .sort((left, right) => right.tokens - left.tokens || left.label.localeCompare(right.label));
}

function buildAIToolBreakdown(
  events: readonly UsageEvent[],
  totalTokens: number,
  messages: TokenMeteringMessages
): AIToolBreakdownRow[] {
  return DASHBOARD_AI_TOOLS.map((aiTool) => {
    const tokens = events
      .filter((event) => event.ai_tool === aiTool)
      .reduce((sum, event) => sum + event.total_tokens, 0);

    return {
      id: aiTool,
      label: messages.aiToolLabels[aiTool],
      tokens,
      percentage: percentOf(tokens, totalTokens)
    };
  });
}

function isDashboardAIToolEvent(event: UsageEvent): boolean {
  return (DASHBOARD_AI_TOOLS as readonly AITool[]).includes(event.ai_tool);
}

function buildModelBreakdown(
  events: readonly UsageEvent[],
  totalTokens: number,
  messages: TokenMeteringMessages
): BreakdownRow[] {
  const totals = new Map<string, number>();
  for (const event of events) {
    const model = modelKey(event.model);
    totals.set(model, (totals.get(model) ?? 0) + event.total_tokens);
  }

  return Array.from(totals.entries())
    .map(([model, tokens]) => ({
      id: model,
      label: model === "model_unavailable" ? messages.kpis.modelUnavailable : model,
      tokens,
      percentage: percentOf(tokens, totalTokens)
    }))
    .sort((left, right) => right.tokens - left.tokens || left.label.localeCompare(right.label));
}

function buildHotspots(
  events: readonly UsageEvent[],
  totalTokens: number,
  messages: TokenMeteringMessages
): HotspotRow[] {
  return TOKEN_SOURCES.map((source) => {
    const tokens = events.reduce(
      (sum, event) => sum + event.token_breakdown[source],
      0
    );

    return {
      id: source,
      label: messages.tokenSourceLabels[source],
      tokens,
      percentage: percentOf(tokens, totalTokens)
    };
  }).sort((left, right) => right.tokens - left.tokens);
}

function buildSessionTrace(
  events: readonly UsageEvent[],
  messages: TokenMeteringMessages,
  localeName: string,
  timeZone?: string
): SessionTraceRun[] {
  const runs = new Map<string, UsageEvent[]>();
  for (const event of events) {
    const current = runs.get(workItemId(event, localeName, timeZone)) ?? [];
    current.push(event);
    runs.set(workItemId(event, localeName, timeZone), current);
  }

  return Array.from(runs.entries()).map(([workItemId, runEvents]) => {
    const sortedEvents = [...runEvents].sort((left, right) =>
      left.created_at.localeCompare(right.created_at)
    );
    const first = sortedEvents[0];
    const latencySamples = sortedEvents
      .map((event) => event.latency_ms)
      .filter((latency) => latency > 0);

    return {
      workItemId,
      title: first ? workItemTitle(first, messages) : messages.panels.unknownWorkItem,
      totalTokens: sortedEvents.reduce(
        (sum, event) => sum + event.total_tokens,
        0
      ),
      inputTokens: sortedEvents.reduce(
        (sum, event) => sum + event.input_tokens,
        0
      ),
      outputTokens: sortedEvents.reduce(
        (sum, event) => sum + event.output_tokens,
        0
      ),
      latencyMs: latencySamples.length > 0
        ? Math.round(latencySamples.reduce((sum, latency) => sum + latency, 0) / latencySamples.length)
        : null,
      eventCount: sortedEvents.length,
      aiTool: first ? first.ai_tool : "unknown",
      steps: sortedEvents.map((event) => ({
        runId: event.run_id,
        spanId: event.span_id,
        taskType: messages.taskTypeLabels[event.task_type] ?? labelFromSlug(event.task_type),
        stage: messages.usageStageLabels[event.stage] ?? labelFromSlug(event.stage),
        model: modelLabel(event.model, messages),
        inputTokens: event.input_tokens,
        outputTokens: event.output_tokens,
        totalTokens: event.total_tokens,
        tokenBreakdown: event.token_breakdown,
        latencyMs: event.latency_ms > 0 ? event.latency_ms : null,
        createdAt: event.created_at
      }))
    };
  }).sort((left, right) => right.totalTokens - left.totalTokens || left.title.localeCompare(right.title));
}


function percentOf(value: number, total: number): number {
  return total === 0 ? 0 : (value / total) * 100;
}

function labelFromSlug(value: string): string {
  return value
    .split("_")
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function workItemId(event: UsageEvent, localeName: string, timeZone?: string): string {
  return [
    "work",
    event.ai_tool,
    event.task_type,
    event.stage,
    modelKey(event.model),
    localDayBucket(event.created_at, localeName, timeZone)
  ].map(safeIdPart).join("_");
}

function workItemTitle(event: UsageEvent, messages: TokenMeteringMessages): string {
  return [
    messages.aiToolLabels[event.ai_tool],
    messages.taskTypeLabels[event.task_type] ?? labelFromSlug(event.task_type),
    messages.usageStageLabels[event.stage] ?? labelFromSlug(event.stage)
  ].join(" - ");
}

function modelKey(model: string): string {
  const normalized = model.trim().toLowerCase();
  if (
    normalized.length === 0 ||
    normalized === "unknown" ||
    normalized === "unknown_model" ||
    normalized === "model_unknown" ||
    normalized === "unavailable"
  ) {
    return "model_unavailable";
  }
  return model.trim();
}

function modelLabel(model: string, messages: TokenMeteringMessages): string {
  return modelKey(model) === "model_unavailable" ? messages.kpis.modelUnavailable : model;
}

function safeIdPart(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
}

function localDayBucket(value: string, localeName: string, timeZone?: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value.slice(0, 10);

  const parts = new Intl.DateTimeFormat(localeName, {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    ...(timeZone ? { timeZone } : {})
  }).formatToParts(date);
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  const day = parts.find((part) => part.type === "day")?.value;

  if (!year || !month || !day) return value.slice(0, 10);
  return `${year}-${month}-${day}`;
}

const numberFormatters = new Map<string, Intl.NumberFormat>();
const compactNumberFormatters = new Map<string, Intl.NumberFormat>();
const percentageNumberFormatters = new Map<string, Intl.NumberFormat>();

function numberFormatter(localeName: string): Intl.NumberFormat {
  const cached = numberFormatters.get(localeName);
  if (cached) return cached;

  const formatter = new Intl.NumberFormat(localeName);
  numberFormatters.set(localeName, formatter);
  return formatter;
}

function compactNumberFormatter(localeName: string): Intl.NumberFormat {
  const cached = compactNumberFormatters.get(localeName);
  if (cached) return cached;

  const formatter = new Intl.NumberFormat(localeName, {
    maximumFractionDigits: 2
  });
  compactNumberFormatters.set(localeName, formatter);
  return formatter;
}

function percentageNumberFormatter(localeName: string): Intl.NumberFormat {
  const cached = percentageNumberFormatters.get(localeName);
  if (cached) return cached;

  const formatter = new Intl.NumberFormat(localeName, {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1
  });
  percentageNumberFormatters.set(localeName, formatter);
  return formatter;
}
