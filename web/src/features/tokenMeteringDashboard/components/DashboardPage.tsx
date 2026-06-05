import { useState } from "react";
import {
  syncModeContent,
  type DashboardModel
} from "../dashboardModel";
import type { SyncMode } from "../syncSafeUsage";
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

  return (
    <>
      <header className="dashboardHeader">
        <button className="dashboardBrand" onClick={onBack} type="button">
          Spill Meter
        </button>
        <nav className="dashboardNav" aria-label="Dashboard sections">
          <a className="active" href="#overview">
            Overview
          </a>
          <a href="#hotspots">Hotspots</a>
          <a href="#sessions">Sessions</a>
          <a href="#settings">Settings</a>
        </nav>
        <div className="dashboardHeaderActions">
          <button type="button" onClick={onBack}>
            Intro
          </button>
          <div className="accountBadge" aria-label="Signed in demo account">
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
              <h1>Sync Mode Status</h1>
              <div className="liveStatus">
                <span className="statusDot" aria-hidden="true" />
                <p>{syncModeContent[syncMode].status}</p>
              </div>
              <p>{syncModeContent[syncMode].summary}</p>
            </div>
          </div>
          <div className="syncHeroActions">
            <button type="button" onClick={() => setContractPanelOpen(true)}>
              View Configuration
            </button>
            <button
              className="primary"
              type="button"
              onClick={() => setContractPanelOpen(true)}
            >
              Cloud Sync
            </button>
          </div>
        </section>

        <section className="kpiGrid" aria-label="Token key metrics">
          {dashboard.kpis.map((kpi, index) => (
            <KpiTile index={index} kpi={kpi} key={kpi.label} />
          ))}
        </section>

        <section className="cloudPreview glassCard" aria-labelledby="cloud-preview-title">
          <div className="cloudPreviewHeader">
            <div>
              <p className="eyebrow">Cloud dashboard preview</p>
              <h2 id="cloud-preview-title">Sign in will unlock hosted sync.</h2>
              <p>
                Local token aggregation lives in the macOS app. This web surface
                is the future account dashboard and currently shows safe preview
                data only.
              </p>
            </div>
            <div className="cloudPreviewStatus">
              <strong>0</strong>
              <span>cloud rows</span>
              <em>Auth not connected</em>
            </div>
          </div>
        </section>

        <div className="dashboardGrid">
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
        aria-label="Open sync contract"
        className="contractFab"
        onClick={() => setContractPanelOpen(true)}
        type="button"
      >
        i
        <span aria-hidden="true">1</span>
      </button>

      <footer className="dashboardFooter">
        <div>
          <strong>Spill Meter</strong>
          <p>Token counts, safe categories, and explicit sync controls.</p>
        </div>
        <nav aria-label="Footer links">
          <a href="#settings">Privacy</a>
          <a href="#overview">Overview</a>
        </nav>
      </footer>
    </>
  );
}
