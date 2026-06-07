import {
  formatTokens,
  type DashboardModel
} from "../../tokenMeteringDashboard/dashboardModel";
import type {
  DashboardDailyUsage,
  DashboardDeviceUsage
} from "../model/dashboardPreview";
import { MaterialIcon } from "../components/MaterialIcon";

const toolColors = ["var(--secondary-container)", "var(--primary-container)", "var(--secondary-fixed-dim)"];

function heatmapIntensity(dayIndex: number, hour: number, dayTokens: number, maxTokens: number): number {
  if (maxTokens === 0 || dayTokens === 0) return 0;

  const dayWeight = dayTokens / maxTokens;
  const workingHourWeight = hour >= 9 && hour <= 19 ? 1 : 0.38;
  const rhythm = ((hour * 7 + dayIndex * 11) % 5) / 10;
  return Math.min(4, Math.max(1, Math.round(dayWeight * workingHourWeight * 3.2 + rhythm)));
}

export function DashboardKpiStrip({
  dashboard
}: {
  dashboard: DashboardModel;
}) {
  return (
    <section className="kpiStrip" aria-label="Dashboard metrics">
      {dashboard.kpis.map((kpi, index) => (
        <article className="portalCard kpiCard" key={kpi.id}>
          <div className="kpiTop">
            <span className={index === 1 ? "kpiIcon blue" : index === 2 ? "kpiIcon slate" : "kpiIcon"}>
              <MaterialIcon name={index === 3 ? "speed" : index === 2 ? "payments" : "toll"} />
            </span>
            <small>{index === 1 ? "Input" : index === 2 ? "Output" : index === 3 ? "Latency" : "Total"}</small>
          </div>
          <span className="kpiLabel">{kpi.label}</span>
          <strong>{kpi.value}</strong>
          <p>{kpi.detail}</p>
        </article>
      ))}
    </section>
  );
}

export function ToolDistributionBlock({
  dashboard
}: {
  dashboard: DashboardModel;
}) {
  const maxToolPercent = Math.max(
    1,
    ...dashboard.aiToolBreakdown.map((row) => row.percentage)
  );

  return (
    <article className="portalCard chartCard toolDistribution">
      <div className="cardHeader">
        <div>
          <h2>AI Tool Distribution</h2>
          <p>Usage by local tool</p>
        </div>
        <button aria-label="More options" type="button">
          <MaterialIcon name="more_vert" />
        </button>
      </div>
      <div className="barChart" aria-label="AI tool distribution bars">
        {dashboard.aiToolBreakdown.map((row, index) => (
          <div className="barColumn" key={row.id}>
            <span
              style={{
                background: toolColors[index % toolColors.length],
                height: row.tokens === 0
                  ? "0%"
                  : `${Math.max(14, (row.percentage / maxToolPercent) * 88)}%`
              }}
            />
            <strong>{row.label}</strong>
          </div>
        ))}
      </div>
    </article>
  );
}

export function WorkflowBreakdownBlock({
  dashboard
}: {
  dashboard: DashboardModel;
}) {
  return (
    <article className="portalCard workflowCard">
      <div className="cardHeader">
        <div>
          <h2>Workflow Breakdown</h2>
          <p>Workflow stages by token volume</p>
        </div>
      </div>
      <div className="workflowList">
        {dashboard.taskBreakdown.slice(0, 5).map((row) => (
          <div className="workflowRow" key={row.id}>
            <div>
              <span>{row.label}</span>
              <strong>{Math.round(row.percentage)}%</strong>
            </div>
            <i>
              <span style={{ width: `${Math.max(8, row.percentage)}%` }} />
            </i>
          </div>
        ))}
      </div>
      <div className="legendRow">
        <span><i className="legendPrimary" /> Fast</span>
        <span><i className="legendBlue" /> Normal</span>
        <span><i className="legendMuted" /> Congested</span>
      </div>
    </article>
  );
}

export function DeviceUsageBlock({
  devices,
  selectedScopeId,
  onSelectScope
}: {
  devices: readonly DashboardDeviceUsage[];
  selectedScopeId: string;
  onSelectScope: (scopeId: string) => void;
}) {
  const totalTokens = devices.reduce((sum, device) => sum + device.totalTokens, 0);
  const totalEvents = devices.reduce((sum, device) => sum + device.eventCount, 0);

  return (
    <article className="portalCard deviceUsageCard">
      <div className="cardHeader">
        <div>
          <h2>PC Usage</h2>
          <p>Mac-level usage comparison</p>
        </div>
      </div>
      <div className="deviceUsageList">
        <button
          className={`deviceUsageAll ${selectedScopeId === "all" ? "active" : ""}`}
          onClick={() => onSelectScope("all")}
          type="button"
        >
          <span>
            <strong>All Macs</strong>
            <small>Combined view</small>
          </span>
          <span className="deviceUsageMetric">
            <strong>{formatTokens(totalTokens)}</strong>
            <small>{totalEvents} events</small>
          </span>
        </button>
        {devices.map((device) => (
          <button
            className={`deviceUsageItem ${selectedScopeId === device.id ? "active" : ""}`}
            key={device.id}
            onClick={() => onSelectScope(device.id)}
            type="button"
          >
            <span>
              <strong>{device.label}</strong>
              <small>{device.detail}</small>
            </span>
            <span className="deviceUsageMetric">
              <strong>{formatTokens(device.totalTokens)}</strong>
              <small>{device.eventCount} events</small>
            </span>
            <i>
              <span style={{ width: `${Math.max(8, device.percentage)}%` }} />
            </i>
            <div className="deviceToolStack" aria-label={`${device.label} AI tool split`}>
              {device.aiToolBreakdown.map((tool, index) => (
                <span
                  key={tool.id}
                  style={{
                    background: toolColors[index % toolColors.length],
                    width: tool.tokens === 0 ? "0%" : `${Math.max(4, tool.percentage)}%`
                  }}
                  title={`${tool.label}: ${formatTokens(tool.tokens)}`}
                />
              ))}
            </div>
            <div className="deviceToolBreakdown">
              {device.aiToolBreakdown.map((tool, index) => (
                <span key={tool.id}>
                  <i style={{ background: toolColors[index % toolColors.length] }} />
                  {tool.label}
                  <strong>{formatTokens(tool.tokens)}</strong>
                </span>
              ))}
            </div>
          </button>
        ))}
      </div>
    </article>
  );
}

export function DailyUsageBlock({
  dailyUsage
}: {
  dailyUsage: readonly DashboardDailyUsage[];
}) {
  const maxDailyTokens = Math.max(1, ...dailyUsage.map((day) => day.totalTokens));

  return (
    <article className="portalCard dailyUsageCard">
      <div className="cardHeader">
        <div>
          <h2>Period Usage</h2>
          <p>Selected period split by AI tool</p>
        </div>
      </div>
      <div className="dailyUsageList">
        {dailyUsage.map((day) => (
          <div className="dailyUsageRow" key={day.id}>
            <div className="dailyUsageLabel">
              <strong>{day.label}</strong>
              <span>{day.detail}</span>
            </div>
            <div className="dailyUsageBar" aria-label={`${day.label} usage by AI tool`}>
              {day.aiToolBreakdown.map((tool, index) => (
                <span
                  key={tool.id}
                  style={{
                    background: toolColors[index % toolColors.length],
                    width: tool.tokens === 0 ? "0%" : `${Math.max(4, tool.percentage)}%`
                  }}
                  title={`${tool.label}: ${formatTokens(tool.tokens)}`}
                />
              ))}
            </div>
            <div className="dailyUsageMetric">
              <strong>{formatTokens(day.totalTokens)}</strong>
              <span>{Math.round((day.totalTokens / maxDailyTokens) * 100)}% of peak</span>
            </div>
          </div>
        ))}
      </div>
      <div className="toolMiniLegend">
        {dailyUsage[0]?.aiToolBreakdown.map((tool, index) => (
          <span key={tool.id}>
            <i style={{ background: toolColors[index % toolColors.length] }} />
            {tool.label}
          </span>
        ))}
      </div>
    </article>
  );
}

export function UsageIntensityBlock({
  dailyUsage
}: {
  dailyUsage: readonly DashboardDailyUsage[];
}) {
  const maxDailyTokens = Math.max(1, ...dailyUsage.map((day) => day.totalTokens));

  return (
    <article className="portalCard heatmapCard">
      <div className="cardHeader">
        <div>
          <h2>Usage Intensity</h2>
          <p>Hourly shape for the selected period</p>
        </div>
        <div className="heatLegend" aria-hidden="true">
          <span>Less</span>
          {[0, 1, 2, 3, 4].map((value) => (
            <i className={`heat-${value}`} key={value} />
          ))}
          <span>More</span>
        </div>
      </div>
      <div className="heatmapLayout">
        <div className="heatDays" aria-hidden="true">
          {dailyUsage.map((day) => (
            <span key={day.id}>{day.label}</span>
          ))}
        </div>
        <div className="heatmapGrid" aria-label="Period usage intensity">
          {dailyUsage.flatMap((day, dayIndex) =>
            Array.from({ length: 24 }, (_, hour) => (
              <span
                className={`heat-${heatmapIntensity(dayIndex, hour, day.totalTokens, maxDailyTokens)}`}
                key={`${day.id}-${hour}`}
                title={`${day.label} ${String(hour).padStart(2, "0")}:00`}
              />
            ))
          )}
        </div>
      </div>
    </article>
  );
}
