import {
  buildDashboardModel,
  type AIToolBreakdownRow,
  type DashboardModel
} from "../../tokenMeteringDashboard/dashboardModel.ts";
import {
  DASHBOARD_AI_TOOLS,
  type AITool,
  type TokenBreakdown,
  type UsageEvent
} from "../../tokenMeteringDashboard/syncSafeUsage.ts";
import { getTokenMeteringMessages } from "../../tokenMeteringDashboard/i18n.ts";

export type DashboardDailyUsage = {
  readonly id: string;
  readonly label: string;
  readonly detail: string;
  readonly totalTokens: number;
  readonly eventCount: number;
  readonly aiToolBreakdown: readonly AIToolBreakdownRow[];
};

export type DashboardDeviceUsage = {
  readonly id: string;
  readonly label: string;
  readonly detail: string;
  readonly totalTokens: number;
  readonly eventCount: number;
  readonly percentage: number;
  readonly aiToolBreakdown: readonly AIToolBreakdownRow[];
};

export type DashboardFilterOption = {
  readonly id: string;
  readonly label: string;
  readonly detail: string;
};

export type DashboardAiFilterId = "all" | AITool;
export type DashboardPeriodFilterId = "1d" | "7d" | "month" | "year";

export type DashboardAiFilterOption = DashboardFilterOption & {
  readonly id: DashboardAiFilterId;
};

export type DashboardPeriodFilterOption = DashboardFilterOption & {
  readonly id: DashboardPeriodFilterId;
};

export type DashboardScopeModel = DashboardFilterOption;

export type PortalDashboardPreviewView = {
  readonly selectedScope: DashboardScopeModel;
  readonly selectedDate: DashboardPeriodFilterOption;
  readonly selectedAiTool: DashboardAiFilterOption;
  readonly dashboard: DashboardModel;
  readonly dailyUsage: readonly DashboardDailyUsage[];
  readonly devices: readonly DashboardDeviceUsage[];
};

export type PortalDashboardPreviewModel = {
  readonly defaultScopeId: string;
  readonly defaultDateId: DashboardPeriodFilterId;
  readonly defaultAiToolId: DashboardAiFilterId;
  readonly scopes: readonly DashboardScopeModel[];
  readonly dateFilters: readonly DashboardPeriodFilterOption[];
  readonly aiFilters: readonly DashboardAiFilterOption[];
};

export type PortalDashboardPreviewFilters = {
  readonly scopeId: string;
  readonly dateId: DashboardPeriodFilterId;
  readonly aiToolId: DashboardAiFilterId;
};

type PreviewDevice = {
  readonly id: string;
  readonly label: string;
  readonly detail: string;
};

type PreviewToolProfile = {
  readonly aiTool: AITool;
  readonly taskTypes: readonly string[];
  readonly stages: readonly string[];
  readonly model: string;
  readonly inputBase: number;
  readonly outputBase: number;
};

type PreviewEventSeed = {
  readonly date: string;
  readonly deviceId: string;
  readonly aiTool: AITool;
  readonly taskType: string;
  readonly stage: string;
  readonly model: string;
  readonly inputTokens: number;
  readonly outputTokens: number;
  readonly latencyMs: number;
};

const previewAnchorDay = "2026-06-07";

const previewDevices: readonly PreviewDevice[] = [
  {
    id: "device_macbook_pro",
    label: "MacBook Pro",
    detail: "Primary laptop"
  },
  {
    id: "device_studio_mac",
    label: "Studio Mac",
    detail: "Desk workstation"
  }
];

const previewToolProfiles: readonly PreviewToolProfile[] = [
  {
    aiTool: "codex",
    taskTypes: ["code_generation", "test_generation", "debugging", "refactoring"],
    stages: ["implement", "verify", "revise"],
    model: "gpt-5-codex",
    inputBase: 42_000,
    outputBase: 29_000
  },
  {
    aiTool: "claude",
    taskTypes: ["analysis", "code_review", "documentation", "architecture"],
    stages: ["plan", "draft", "revise", "summarize"],
    model: "claude-sonnet-4.5",
    inputBase: 36_000,
    outputBase: 22_000
  },
  {
    aiTool: "antigravity",
    taskTypes: ["ui_design", "architecture", "analysis", "workflow_setup"],
    stages: ["draft", "plan", "implement", "summarize"],
    model: "gemini-3-pro",
    inputBase: 24_000,
    outputBase: 18_000
  }
];

const previewSeeds: readonly PreviewEventSeed[] = buildPreviewSeeds();
const previewEvents: readonly UsageEvent[] = previewSeeds.map((eventSeed, index) =>
  usageEventFromSeed(eventSeed, index)
);

export function buildPortalDashboardPreviewModel(): PortalDashboardPreviewModel {
  return {
    defaultScopeId: "all",
    defaultDateId: "1d",
    defaultAiToolId: "all",
    scopes: [
      {
        id: "all",
        label: "All Macs",
        detail: "Every connected Mac"
      },
      ...previewDevices.map((device) => ({
        id: device.id,
        label: device.label,
        detail: device.detail
      }))
    ],
    dateFilters: buildPeriodFilters(),
    aiFilters: buildAiFilters()
  };
}

export function buildPortalDashboardPreviewView(
  filters: PortalDashboardPreviewFilters
): PortalDashboardPreviewView {
  const model = buildPortalDashboardPreviewModel();
  const selectedScope = findOption(model.scopes, filters.scopeId) ?? model.scopes[0];
  const selectedDate = findOption(model.dateFilters, filters.dateId) ?? model.dateFilters[0];
  const selectedAiTool = findOption(model.aiFilters, filters.aiToolId) ?? model.aiFilters[0];

  const dateAndAiEvents = previewEvents.filter((event) =>
    matchesPeriod(event, selectedDate.id) &&
    matchesAiTool(event, selectedAiTool.id)
  );
  const scopedEvents = dateAndAiEvents.filter((event) =>
    selectedScope.id === "all" || event.device_id === selectedScope.id
  );
  const deviceTotal = sumTokens(dateAndAiEvents);

  return {
    selectedScope,
    selectedDate,
    selectedAiTool,
    dashboard: buildDashboardModel(scopedEvents),
    dailyUsage: buildPeriodUsage(scopedEvents, selectedDate.id),
    devices: previewDevices.map((device) => {
      const deviceEvents = dateAndAiEvents.filter((event) => event.device_id === device.id);
      const totalTokens = sumTokens(deviceEvents);

      return {
        id: device.id,
        label: device.label,
        detail: device.detail,
        totalTokens,
        eventCount: deviceEvents.length,
        percentage: percentOf(totalTokens, deviceTotal),
        aiToolBreakdown: buildToolBreakdown(deviceEvents)
      };
    })
  };
}

function buildPreviewSeeds(): readonly PreviewEventSeed[] {
  const anchor = dateForDay(previewAnchorDay);
  const seeds: PreviewEventSeed[] = [];

  for (let dayOffset = 364; dayOffset >= 0; dayOffset -= 1) {
    const dayIndex = 364 - dayOffset;
    const date = isoDay(addUtcDays(anchor, -dayOffset));
    for (const [deviceIndex, device] of previewDevices.entries()) {
      for (const [toolIndex, profile] of previewToolProfiles.entries()) {
        const intensity = dailyIntensity(dayIndex, deviceIndex, toolIndex);
        seeds.push(seed(
          date,
          device.id,
          profile.aiTool,
          pick(profile.taskTypes, dayIndex + deviceIndex),
          pick(profile.stages, dayIndex + toolIndex),
          profile.model,
          Math.round(profile.inputBase * intensity),
          Math.round(profile.outputBase * intensity),
          620 + ((dayIndex * 37 + deviceIndex * 71 + toolIndex * 43) % 430)
        ));
      }
    }
  }

  return seeds;
}

function dailyIntensity(dayIndex: number, deviceIndex: number, toolIndex: number): number {
  const weekday = dayIndex % 7;
  const workdayFactor = weekday === 5 || weekday === 6 ? 0.58 : 1;
  const monthWave = 0.86 + ((dayIndex % 31) / 100);
  const toolWave = 0.94 + (((dayIndex + toolIndex * 3) % 9) / 50);
  const deviceFactor = deviceIndex === 0 ? 1.18 : 0.92;

  return workdayFactor * monthWave * toolWave * deviceFactor;
}

function seed(
  date: string,
  deviceId: string,
  aiTool: AITool,
  taskType: string,
  stage: string,
  model: string,
  inputTokens: number,
  outputTokens: number,
  latencyMs: number
): PreviewEventSeed {
  return {
    date,
    deviceId,
    aiTool,
    taskType,
    stage,
    model,
    inputTokens,
    outputTokens,
    latencyMs
  };
}

function usageEventFromSeed(eventSeed: PreviewEventSeed, index: number): UsageEvent {
  const ordinal = `${index + 1}`.padStart(4, "0");

  return {
    schema_version: 1,
    device_id: eventSeed.deviceId,
    project_id: "project_global",
    artifact_id: "artifact_global",
    run_id: `run_preview_${ordinal}`,
    span_id: `span_preview_${ordinal}`,
    ai_tool: eventSeed.aiTool,
    task_type: eventSeed.taskType,
    stage: eventSeed.stage,
    model: eventSeed.model,
    input_tokens: eventSeed.inputTokens,
    output_tokens: eventSeed.outputTokens,
    total_tokens: eventSeed.inputTokens + eventSeed.outputTokens,
    token_breakdown: tokenBreakdown(eventSeed.inputTokens, eventSeed.outputTokens),
    latency_ms: eventSeed.latencyMs,
    created_at: `${eventSeed.date}T12:00:00.000Z`
  };
}

function tokenBreakdown(inputTokens: number, outputTokens: number): TokenBreakdown {
  const system = Math.round(inputTokens * 0.08);
  const user = Math.round(inputTokens * 0.18);
  const history = Math.round(inputTokens * 0.22);
  const repoContext = Math.round(inputTokens * 0.32);
  const toolOutput = Math.round(inputTokens * 0.12);
  const unknown = inputTokens - system - user - history - repoContext - toolOutput;

  return {
    system,
    user,
    history,
    repo_context: repoContext,
    tool_output: toolOutput,
    generated_output: outputTokens,
    unknown
  };
}

function buildPeriodUsage(
  events: readonly UsageEvent[],
  periodId: DashboardPeriodFilterId
): readonly DashboardDailyUsage[] {
  const buckets = new Map<string, UsageEvent[]>();
  for (const event of events) {
    const bucket = periodBucket(event.created_at.slice(0, 10), periodId);
    buckets.set(bucket.id, [...(buckets.get(bucket.id) ?? []), event]);
  }

  return Array.from(buckets.entries())
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([bucketId, bucketEvents]) => {
      const bucket = periodBucket(bucketEvents[0]?.created_at.slice(0, 10) ?? previewAnchorDay, periodId);
      return {
        id: bucketId,
        label: bucket.label,
        detail: bucket.detail,
        totalTokens: sumTokens(bucketEvents),
        eventCount: bucketEvents.length,
        aiToolBreakdown: buildToolBreakdown(bucketEvents)
      };
    });
}

function buildPeriodFilters(): readonly DashboardPeriodFilterOption[] {
  return [
    {
      id: "1d",
      label: "1D",
      detail: "Latest day"
    },
    {
      id: "7d",
      label: "7D",
      detail: "Rolling week"
    },
    {
      id: "month",
      label: "Month",
      detail: "30 rolling days"
    },
    {
      id: "year",
      label: "Year",
      detail: "Last 12 months"
    }
  ];
}

function buildAiFilters(): readonly DashboardAiFilterOption[] {
  const messages = getTokenMeteringMessages();

  return [
    {
      id: "all",
      label: "All AI",
      detail: "Codex, Claude, Antigravity"
    },
    ...DASHBOARD_AI_TOOLS.map((aiTool) => ({
      id: aiTool,
      label: messages.aiToolLabels[aiTool],
      detail: "Single tool"
    }))
  ];
}

function buildToolBreakdown(events: readonly UsageEvent[]): readonly AIToolBreakdownRow[] {
  const messages = getTokenMeteringMessages();
  const totalTokens = sumTokens(events);

  return DASHBOARD_AI_TOOLS.map((aiTool) => {
    const tokens = sumTokens(events.filter((event) => event.ai_tool === aiTool));

    return {
      id: aiTool,
      label: messages.aiToolLabels[aiTool],
      tokens,
      percentage: percentOf(tokens, totalTokens)
    };
  });
}

function matchesPeriod(event: UsageEvent, periodId: DashboardPeriodFilterId): boolean {
  const day = event.created_at.slice(0, 10);
  const start = periodStartDay(periodId);
  return day >= start && day <= previewAnchorDay;
}

function matchesAiTool(event: UsageEvent, aiToolId: DashboardAiFilterId): boolean {
  return aiToolId === "all" || event.ai_tool === aiToolId;
}

function findOption<TOption extends { readonly id: string }>(
  options: readonly TOption[],
  id: string
): TOption | undefined {
  return options.find((option) => option.id === id);
}

function sumTokens(events: readonly UsageEvent[]): number {
  return events.reduce((sum, event) => sum + event.total_tokens, 0);
}

function percentOf(value: number, total: number): number {
  return total === 0 ? 0 : (value / total) * 100;
}

function periodStartDay(periodId: DashboardPeriodFilterId): string {
  const anchor = dateForDay(previewAnchorDay);
  if (periodId === "1d") return previewAnchorDay;
  if (periodId === "7d") return isoDay(addUtcDays(anchor, -6));
  if (periodId === "month") return isoDay(addUtcDays(anchor, -29));
  return isoDay(new Date(Date.UTC(anchor.getUTCFullYear(), anchor.getUTCMonth() - 11, 1, 12)));
}

function periodBucket(
  day: string,
  periodId: DashboardPeriodFilterId
): { id: string; label: string; detail: string } {
  if (periodId === "year") {
    return {
      id: day.slice(0, 7),
      label: dateFormatter({ month: "short" }).format(dateForDay(day)),
      detail: day.slice(0, 4)
    };
  }

  if (periodId === "month") {
    const weekNumber = Math.floor(daysBetween(periodStartDay("month"), day) / 7) + 1;
    return {
      id: `${periodStartDay("month")}_week_${weekNumber}`,
      label: `Week ${weekNumber}`,
      detail: "30-day window"
    };
  }

  return {
    id: day,
    label: dayLabel(day),
    detail: weekdayLabel(day)
  };
}

function pick<T>(items: readonly T[], index: number): T {
  return items[index % items.length];
}

function dayLabel(day: string): string {
  return dateFormatter({ month: "short", day: "numeric" }).format(dateForDay(day));
}

function weekdayLabel(day: string): string {
  return dateFormatter({ weekday: "long" }).format(dateForDay(day));
}

function dateForDay(day: string): Date {
  return new Date(`${day}T12:00:00.000Z`);
}

function addUtcDays(date: Date, days: number): Date {
  const copy = new Date(date);
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
}

function daysBetween(startDay: string, endDay: string): number {
  const start = dateForDay(startDay).getTime();
  const end = dateForDay(endDay).getTime();
  return Math.floor((end - start) / 86_400_000);
}

function isoDay(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function dateFormatter(options: Intl.DateTimeFormatOptions): Intl.DateTimeFormat {
  return new Intl.DateTimeFormat("en-US", {
    timeZone: "UTC",
    ...options
  });
}
