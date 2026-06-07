import type { DashboardModel } from "../../tokenMeteringDashboard/dashboardModel";
import {
  DashboardKpiStrip,
  ToolDistributionBlock,
  UsageIntensityBlock,
  WorkflowBreakdownBlock
} from "../blocks/DashboardBlocks";
import { AppChrome } from "../components/AppChrome";
import type { SpillAuthProvider, SpillAuthState } from "../model/spillAuth";
import type { PortalRoute } from "../routes";

export function DashboardScreen({
  auth,
  dashboard,
  onNavigate,
  onSignIn,
  onSignOut
}: {
  auth: SpillAuthState;
  dashboard: DashboardModel;
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  return (
    <AppChrome
      activeRoute="dashboard"
      auth={auth}
      onNavigate={onNavigate}
      onSignIn={onSignIn}
      onSignOut={onSignOut}
    >
      <div className="pageHeader">
        <div>
          <h1>Usage Overview</h1>
          <p>Local usage totals and activity patterns</p>
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
      </section>
    </AppChrome>
  );
}
