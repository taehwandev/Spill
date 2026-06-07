import type { DashboardModel } from "../../tokenMeteringDashboard/dashboardModel";
import {
  DashboardKpiStrip,
  DesktopAppRequiredBlock,
  DeviceSummaryBlock,
  SyncSecuritySummaryBlock,
  ToolDistributionBlock,
  UsageIntensityBlock,
  WorkflowBreakdownBlock
} from "../blocks/DashboardBlocks";
import { AppChrome } from "../components/AppChrome";
import type { PortalRoute } from "../routes";

export function DashboardScreen({
  dashboard,
  onNavigate
}: {
  dashboard: DashboardModel;
  onNavigate: (route: PortalRoute) => void;
}) {
  return (
    <AppChrome activeRoute="dashboard" onNavigate={onNavigate}>
      <div className="pageHeader">
        <div>
          <h1>System Performance</h1>
          <p>Real-time inference and token usage analysis</p>
        </div>
        <div className="rangeControl" aria-label="Time range">
          <button type="button">Day</button>
          <button className="active" type="button">Week</button>
          <button type="button">Month</button>
          <button type="button">Year</button>
        </div>
      </div>

      <DashboardKpiStrip dashboard={dashboard} />

      <section className="dashboardBento">
        <ToolDistributionBlock dashboard={dashboard} />
        <WorkflowBreakdownBlock dashboard={dashboard} />
        <UsageIntensityBlock />
        <DesktopAppRequiredBlock />
        <DeviceSummaryBlock onNavigate={onNavigate} />
        <SyncSecuritySummaryBlock />
      </section>
    </AppChrome>
  );
}
