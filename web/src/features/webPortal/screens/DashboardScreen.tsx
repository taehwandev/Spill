import { useMemo, useState } from "react";
import type { DashboardModel } from "../../tokenMeteringDashboard/dashboardModel";
import {
  DailyUsageBlock,
  DashboardKpiStrip,
  DeviceUsageBlock,
  ToolDistributionBlock,
  UsageIntensityBlock,
  WorkflowBreakdownBlock
} from "../blocks/DashboardBlocks";
import { AppChrome } from "../components/AppChrome";
import {
  buildPortalDashboardPreviewView,
  type DashboardAiFilterId,
  type DashboardPeriodFilterId,
  type PortalDashboardPreviewModel
} from "../model/dashboardPreview";
import type {
  SpillAuthProvider,
  SpillAuthProviderOption,
  SpillAuthState
} from "../model/spillAuth";
import type { PortalRoute } from "../routes";

export function DashboardScreen({
  auth,
  authProviders,
  dashboardPreview,
  onNavigate,
  onSignIn,
  onSignOut
}: {
  auth: SpillAuthState;
  authProviders: readonly SpillAuthProviderOption[];
  dashboardPreview: PortalDashboardPreviewModel;
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  const [selectedScopeId, setSelectedScopeId] = useState(dashboardPreview.defaultScopeId);
  const [selectedDateId, setSelectedDateId] = useState<DashboardPeriodFilterId>(
    dashboardPreview.defaultDateId
  );
  const [selectedAiToolId, setSelectedAiToolId] = useState<DashboardAiFilterId>(
    dashboardPreview.defaultAiToolId
  );
  const dashboardView = useMemo(() => buildPortalDashboardPreviewView({
    aiToolId: selectedAiToolId,
    dateId: selectedDateId,
    scopeId: selectedScopeId
  }), [selectedAiToolId, selectedDateId, selectedScopeId]);
  const dashboard: DashboardModel = dashboardView.dashboard;

  return (
    <AppChrome
      activeRoute="dashboard"
      auth={auth}
      authProviders={authProviders}
      onNavigate={onNavigate}
      onSignIn={onSignIn}
      onSignOut={onSignOut}
    >
      <div className="pageHeader">
        <div>
          <h1>Usage Overview</h1>
          <p>Local aggregate usage by period, AI tool, and Mac</p>
        </div>
        <div className="rangeControl" aria-label="Time range">
          {dashboardPreview.dateFilters.map((dateFilter) => (
            <button
              className={dateFilter.id === dashboardView.selectedDate.id ? "active" : ""}
              key={dateFilter.id}
              onClick={() => setSelectedDateId(dateFilter.id)}
              type="button"
            >
              {dateFilter.label}
            </button>
          ))}
        </div>
      </div>

      <div className="dashboardFilterBar" aria-label="AI filter">
        {dashboardPreview.aiFilters.map((aiFilter) => (
          <button
            className={aiFilter.id === dashboardView.selectedAiTool.id ? "active" : ""}
            key={aiFilter.id}
            onClick={() => setSelectedAiToolId(aiFilter.id)}
            type="button"
          >
            <span>{aiFilter.label}</span>
            <small>{aiFilter.detail}</small>
          </button>
        ))}
      </div>

      <DashboardKpiStrip dashboard={dashboard} />

      <section className="dashboardBento">
        <ToolDistributionBlock dashboard={dashboard} />
        <DeviceUsageBlock
          devices={dashboardView.devices}
          selectedScopeId={dashboardView.selectedScope.id}
          onSelectScope={setSelectedScopeId}
        />
        <DailyUsageBlock dailyUsage={dashboardView.dailyUsage} />
        <WorkflowBreakdownBlock dashboard={dashboard} />
        <UsageIntensityBlock dailyUsage={dashboardView.dailyUsage} />
      </section>
    </AppChrome>
  );
}
