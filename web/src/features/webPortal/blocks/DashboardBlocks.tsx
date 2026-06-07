import type { DashboardModel } from "../../tokenMeteringDashboard/dashboardModel";
import { ConnectedDeviceList } from "../components/ConnectedDeviceList";
import { MaterialIcon } from "../components/MaterialIcon";
import { SecurityControlGrid } from "../components/SecurityControlGrid";
import { connectedDevices } from "../model/syncSecurityPolicy";
import type { PortalRoute } from "../routes";

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
            <small>{index === 1 ? "Input" : index === 2 ? "Output" : index === 3 ? "Latency" : "Synced"}</small>
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
          <p>Inference volume by local agent</p>
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
          <p>Processing stages by token volume</p>
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
        <div className="heatmapGrid" aria-label="Weekly usage intensity preview">
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

export function DesktopAppRequiredBlock() {
  return (
    <article className="portalCard deviceRequiredPanel">
      <img
        alt="Spill desktop dashboard preview"
        src="https://lh3.googleusercontent.com/aida-public/AB6AXuBOZToIICiW6_wCepIGos78UcZCotrbXUDc1cSOU7uR8rVCoSEkOKZGJC3CPK50K1I15U4E_shsVRwe4Wiood5D5Ggz5qEz9AB2CYacRQm2u8IjqWD3OELzCUjRkDEFPKebfkK60JBN27nuZ6x5rT4awd5-dSI_CubjUNUySfr-LPAIoaCNRiKUV7XAUDg_XkGQzIKXBUOlidKrYB45HNwjVHi3Jjccd5uDo1gFRQkTrBv74h_9dWtcnqSONTrbFfvGu4PvYJ5cNVM"
      />
      <div>
        <span>Connected</span>
        <h2>Desktop App Required</h2>
        <p>Connect your local Spill instance to sync safe AI usage totals to this web dashboard.</p>
        <button type="button">
          <MaterialIcon name="download" />
          Download Desktop App
        </button>
      </div>
    </article>
  );
}

export function DeviceSummaryBlock({
  onNavigate
}: {
  onNavigate: (route: PortalRoute) => void;
}) {
  return (
    <article className="portalCard deviceSummary">
      <div className="cardHeader">
        <div>
          <h2>Connected Devices</h2>
          <p>{connectedDevices.length} trusted device profiles</p>
        </div>
        <button onClick={() => onNavigate("settings")} type="button">
          Manage
        </button>
      </div>
      <ConnectedDeviceList compact />
    </article>
  );
}

export function SyncSecuritySummaryBlock() {
  return (
    <article className="portalCard securitySummary">
      <div className="cardHeader">
        <div>
          <h2>Sync Security Contract</h2>
          <p>Cloud sync cannot ship until every required control is enforced.</p>
        </div>
      </div>
      <SecurityControlGrid />
    </article>
  );
}
