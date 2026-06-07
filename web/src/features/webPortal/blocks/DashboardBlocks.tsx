import type { DashboardModel } from "../../tokenMeteringDashboard/dashboardModel";
import { MaterialIcon } from "../components/MaterialIcon";

const toolColors = ["var(--secondary-container)", "var(--primary-container)", "var(--secondary-fixed-dim)"];

function heatmapIntensity(index: number): number {
  return (index * 17 + Math.floor(index / 24) * 3 + 2) % 5;
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
                height: `${Math.max(14, (row.percentage / maxToolPercent) * 88)}%`
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

export function UsageIntensityBlock() {
  return (
    <article className="portalCard heatmapCard">
      <div className="cardHeader">
        <div>
          <h2>Usage Intensity</h2>
          <p>Heatmap of activity across the week</p>
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
          <span>Mon</span>
          <span>Wed</span>
          <span>Fri</span>
          <span>Sun</span>
        </div>
        <div className="heatmapGrid" aria-label="Weekly usage intensity">
          {Array.from({ length: 168 }, (_, index) => (
            <span
              className={`heat-${heatmapIntensity(index)}`}
              key={`heat-${index}`}
              title={`Hour ${index + 1}`}
            />
          ))}
        </div>
      </div>
    </article>
  );
}
