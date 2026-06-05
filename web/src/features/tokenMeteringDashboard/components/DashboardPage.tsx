import { useState } from "react";
import { type DashboardModel } from "../dashboardModel";
import { getTokenMeteringMessages } from "../i18n";
import type { SyncMode } from "../syncSafeUsage";
import { AIToolBreakdown } from "./AIToolBreakdown";
import { KpiTile } from "./KpiTile";
import { PrivacySettings } from "./PrivacySettings";
import { SessionTrace } from "./SessionTrace";
import { SourceHotspots } from "./SourceHotspots";
import { SyncContractPanel } from "./SyncContractPanel";
import { TaskBreakdown } from "./TaskBreakdown";

export function DashboardPage({
  dashboard,
  onBack,
  setSyncMode,
  syncMode
}: {
  dashboard: DashboardModel;
  onBack: () => void;
  setSyncMode: (mode: SyncMode) => void;
  syncMode: SyncMode;
}) {
  const [contractPanelOpen, setContractPanelOpen] = useState(false);
  const messages = getTokenMeteringMessages();
  const syncModeContent = messages.syncModeContent;

  return (
    <>
      <header className="dashboardHeader">
        <button className="dashboardBrand" onClick={onBack} type="button">
          {messages.dashboard.brand}
          <span className="alphaBadge">Alpha</span>
        </button>
        <nav className="dashboardNav" aria-label={messages.dashboard.navLabel}>
          <a className="active" href="#overview">
            {messages.nav.overview}
          </a>
          <a href="#hotspots">{messages.nav.hotspots}</a>
          <a href="#sessions">{messages.nav.sessions}</a>
          <a href="#settings">{messages.nav.settings}</a>
        </nav>
        <div className="dashboardHeaderActions">
          <button type="button" onClick={onBack}>
            {messages.nav.intro}
          </button>
          <div className="accountBadge" aria-label={messages.dashboard.accountLabel}>
            SP
          </div>
        </div>
      </header>

      <main className="dashboardMain">
        <section className="syncHero glassCard" id="overview">
          <div className="syncHeroIdentity">
            <div className="syncIcon" aria-hidden="true">
              sync
            </div>
            <div>
              <h1>{messages.dashboard.syncModeStatus}</h1>
              <div className="liveStatus">
                <span className="statusDot" aria-hidden="true" />
                <p>{syncModeContent[syncMode].status}</p>
              </div>
              <p>{syncModeContent[syncMode].summary}</p>
            </div>
          </div>
          <div className="syncHeroActions">
            <button type="button" onClick={() => setContractPanelOpen(true)}>
              {messages.dashboard.viewConfiguration}
            </button>
            <button
              className="primary"
              type="button"
              onClick={() => setContractPanelOpen(true)}
            >
              {messages.dashboard.cloudSync}
            </button>
          </div>
        </section>

        <section className="kpiGrid" aria-label={messages.dashboard.kpiAria}>
          {dashboard.kpis.map((kpi, index) => (
            <KpiTile index={index} kpi={kpi} key={kpi.id} />
          ))}
        </section>

        <section className="cloudPreview glassCard" aria-labelledby="cloud-preview-title">
          <div className="cloudPreviewHeader">
            <div>
              <p className="eyebrow">{messages.dashboard.cloudPreviewTitle}</p>
              <h2 id="cloud-preview-title">{messages.dashboard.cloudPreviewHeading}</h2>
              <p>
                {messages.dashboard.cloudPreviewBody}
              </p>
            </div>
            <div className="cloudPreviewStatus">
              <strong>0</strong>
              <span>{messages.dashboard.cloudRows}</span>
              <em>{messages.dashboard.authNotConnected}</em>
            </div>
          </div>
        </section>

        <div className="dashboardGrid">
          <AIToolBreakdown rows={dashboard.aiToolBreakdown} total={dashboard.totalTokens} />
          <TaskBreakdown rows={dashboard.taskBreakdown} total={dashboard.totalTokens} />
          <SourceHotspots rows={dashboard.hotspots} />
          <SessionTrace runs={dashboard.sessionTrace} />
          <PrivacySettings dashboard={dashboard} syncMode={syncMode} />
        </div>
      </main>

      {contractPanelOpen ? (
        <SyncContractPanel
          dashboard={dashboard}
          onClose={() => setContractPanelOpen(false)}
          setSyncMode={setSyncMode}
          syncMode={syncMode}
        />
      ) : null}

      <button
        aria-expanded={contractPanelOpen}
        aria-label={messages.dashboard.openSyncContract}
        className="contractFab"
        onClick={() => setContractPanelOpen(true)}
        type="button"
      >
        i
        <span aria-hidden="true">1</span>
      </button>

      <footer className="dashboardFooter">
        <div>
          <strong>{messages.dashboard.brand}</strong>
          <p>{messages.dashboard.footerBody}</p>
        </div>
        <nav aria-label={messages.intro.footerLabel}>
          <a href="#settings">{messages.nav.privacy}</a>
          <a href="#overview">{messages.nav.overview}</a>
        </nav>
      </footer>
    </>
  );
}
