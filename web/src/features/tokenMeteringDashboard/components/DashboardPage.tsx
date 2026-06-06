import { useMemo, useState } from "react";
import { buildDashboardModel } from "../dashboardModel";
import { getTokenMeteringMessages } from "../i18n";
import type { SyncMode, UsageEvent } from "../syncSafeUsage";
import { AIToolBreakdown } from "./AIToolBreakdown";
import { KpiTile } from "./KpiTile";
import { PrivacySettings } from "./PrivacySettings";
import { SessionTrace } from "./SessionTrace";
import { SourceHotspots } from "./SourceHotspots";
import { SyncContractPanel } from "./SyncContractPanel";
import { TaskBreakdown } from "./TaskBreakdown";


export function DashboardPage({
  events,
  onBack,
  setSyncMode,
  syncMode,
  onTriggerSelfTest
}: {
  events: readonly UsageEvent[];
  onBack: () => void;
  setSyncMode: (mode: SyncMode) => void;
  syncMode: SyncMode;
  onTriggerSelfTest: () => void;
}) {
  const [contractPanelOpen, setContractPanelOpen] = useState(false);
  const [timeRange, setTimeRange] = useState<"today" | "7days" | "30days" | "all">("today");
  const [showAdvancedTools, setShowAdvancedTools] = useState(false);

  const messages = getTokenMeteringMessages();
  const syncModeContent = messages.syncModeContent;

  const filteredEvents = useMemo(() => {
    let evs = [...events];

    // Agent Filter: Codex, Claude Code, and Antigravity only by default
    if (!showAdvancedTools) {
      evs = evs.filter(
        (e) => e.ai_tool === "codex" || e.ai_tool === "claude" || e.ai_tool === "antigravity"
      );
    }

    // Time Range Filter
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    return evs.filter((e) => {
      const eventDate = new Date(e.created_at);
      if (timeRange === "today") {
        return eventDate >= todayStart;
      } else if (timeRange === "7days") {
        const sevenDaysAgo = new Date(todayStart.getTime() - 7 * 24 * 60 * 60 * 1000);
        return eventDate >= sevenDaysAgo;
      } else if (timeRange === "30days") {
        const thirtyDaysAgo = new Date(todayStart.getTime() - 30 * 24 * 60 * 60 * 1000);
        return eventDate >= thirtyDaysAgo;
      }
      return true; // "all"
    });
  }, [events, timeRange, showAdvancedTools]);

  const dashboard = useMemo(() => buildDashboardModel(filteredEvents), [filteredEvents]);

  // Info content for tooltip
  const kpiInfoText = "Usage aggregates represent strictly token counts, latency, and safe enums. Raw prompts or code are never processed.";

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

        {/* Filter Controls Row */}
        <section className="dashboardFilters glassCard">
          <div className="filterGroup">
            <span className="filterLabel">Time Range</span>
            <div className="segmentedControl">
              <button
                className={timeRange === "today" ? "active" : ""}
                onClick={() => setTimeRange("today")}
                type="button"
              >
                Today
              </button>
              <button
                className={timeRange === "7days" ? "active" : ""}
                onClick={() => setTimeRange("7days")}
                type="button"
              >
                7 Days
              </button>
              <button
                className={timeRange === "30days" ? "active" : ""}
                onClick={() => setTimeRange("30days")}
                type="button"
              >
                30 Days
              </button>
              <button
                className={timeRange === "all" ? "active" : ""}
                onClick={() => setTimeRange("all")}
                type="button"
              >
                All Time
              </button>
            </div>
          </div>

          <div className="filterGroup">
            <label className="checkboxLabel">
              <input
                checked={showAdvancedTools}
                onChange={(e) => setShowAdvancedTools(e.target.checked)}
                type="checkbox"
              />
              Show all tools (including unknown & OpenAI SDK)
            </label>
          </div>
        </section>

        <section className="kpiSection">
          <div className="kpiSectionHeader">
            <h2>
              Key Metrics
              <span className="infoIcon" title={kpiInfoText}>ⓘ</span>
            </h2>
            <span className="kpiBasis">
              Accumulation window: <strong>{timeRange === "today" ? "Today" : timeRange === "7days" ? "Last 7 Days" : timeRange === "30days" ? "Last 30 Days" : "All Time"}</strong>
            </span>
          </div>
          <div className="kpiGrid" aria-label={messages.dashboard.kpiAria}>
            {dashboard.kpis.map((kpi, index) => (
              <KpiTile index={index} kpi={kpi} key={kpi.id} />
            ))}
          </div>
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
          <PrivacySettings dashboard={dashboard} syncMode={syncMode} onTriggerSelfTest={onTriggerSelfTest} />
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
