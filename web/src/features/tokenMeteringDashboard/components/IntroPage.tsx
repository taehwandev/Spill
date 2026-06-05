import { formatTokens, type DashboardModel } from "../dashboardModel";
import { getTokenMeteringMessages } from "../i18n";
import {
  installCommand,
  setupPrompt,
  type CopiedTarget
} from "../setupCopy";
import { SetupStep } from "./SetupStep";

export function IntroPage({
  copiedTarget,
  dashboard,
  onCopyInstall,
  onCopySetup,
  onOpenDashboard
}: {
  copiedTarget: CopiedTarget;
  dashboard: DashboardModel;
  onCopyInstall: () => void;
  onCopySetup: () => void;
  onOpenDashboard: () => void;
}) {
  const messages = getTokenMeteringMessages();

  return (
    <>
      <nav className="introNav" aria-label={messages.intro.navLabel}>
        <div className="introBrand">Spill</div>
        <div className="introLinks">
          <a href="#features">{messages.nav.features}</a>
          <a href="#setup">{messages.nav.setup}</a>
          <a href="#about">{messages.nav.about}</a>
          <button className="downloadButton" type="button" onClick={onOpenDashboard}>
            {messages.nav.download}
          </button>
        </div>
      </nav>

      <main className="introMain">
        <section className="previewColumn" aria-label={messages.intro.dashboardPreviewAria}>
          <div className="previewLabel">{messages.intro.cloudDashboardPreview}</div>
          <div>
            <h1>
              {messages.intro.heroLineOne}
              <span>{messages.intro.heroLineTwo}</span>
            </h1>
          </div>

          <div className="previewStack" aria-hidden="true">
            <article className="previewCard large">
              <div className="previewHeader">
                <div>
                  <p>{messages.intro.currentUsage}</p>
                  <strong>{messages.intro.tokenTotal(dashboard.kpis[0]?.value ?? "0")}</strong>
                </div>
                <span className="monitorIcon">
                  <i />
                  <i />
                  <i />
                </span>
              </div>
              <div className="dashboardSnapshot">
                <div className="snapshotTop">
                  <strong>Spill</strong>
                  <span>{messages.intro.tokenMetering}</span>
                </div>
                <div className="snapshotNav">
                  <span>{messages.nav.overview}</span>
                  <span>{messages.nav.hotspots}</span>
                  <span>{messages.nav.sessions}</span>
                  <span>{messages.nav.settings}</span>
                </div>
                <div className="snapshotStatus">
                  <span />
                  {messages.intro.cloudPreviewData}
                </div>
                <div className="snapshotCard">
                  <p>{messages.intro.syncModeStatus}</p>
                  <strong>{messages.intro.cloudNotConnected}</strong>
                  <em>{messages.intro.localDetailUntilSync}</em>
                  <div className="snapshotPills">
                    <span />
                    <span />
                    <span />
                  </div>
                </div>
                <div className="snapshotKpis">
                  {dashboard.kpis.map((kpi) => (
                    <span key={kpi.id}>
                      <small>{kpi.label}</small>
                      <strong>{kpi.value}</strong>
                      <em>{kpi.detail}</em>
                    </span>
                  ))}
                </div>
                <div className="snapshotBars">
                  {dashboard.taskBreakdown.slice(0, 5).map((row) => (
                    <div key={row.id}>
                      <p>
                        <span>{row.label}</span>
                        <em>{formatTokens(row.tokens)}</em>
                      </p>
                      <i style={{ width: `${Math.max(18, row.percentage)}%` }} />
                    </div>
                  ))}
                </div>
              </div>
            </article>

            <div className="previewMiniGrid">
              <article className="previewCard">
                <p>{messages.intro.modelBreakdown}</p>
                <div className="miniDashboard">
                  {dashboard.modelBreakdown.slice(0, 6).map((row) => (
                    <span key={row.id}>
                      <i style={{ width: `${Math.max(16, row.percentage)}%` }} />
                    </span>
                  ))}
                </div>
                <div className="miniMetricRow">
                  <strong>{dashboard.modelBreakdown[0]?.label ?? "-"}</strong>
                  <em>{formatTokens(dashboard.modelBreakdown[0]?.tokens ?? 0)}</em>
                </div>
              </article>
              <article className="previewCard">
                <p>{messages.intro.taskBreakdown}</p>
                <div className="miniDashboard split">
                  {dashboard.hotspots.slice(0, 5).map((row) => (
                    <span key={row.id}>
                      <i style={{ width: `${Math.max(14, row.percentage)}%` }} />
                    </span>
                  ))}
                </div>
                <div className="miniBars">
                  <span />
                </div>
              </article>
            </div>
          </div>
        </section>

        <section className="portalColumn" aria-label="Get started">
          <div className="portalIntro">
            <h2>{messages.intro.headline}</h2>
            <p>
              {messages.intro.body}
            </p>
          </div>

          <div className="authPanel" id="features">
            <button className="githubButton" type="button" onClick={onOpenDashboard}>
              <svg aria-hidden="true" viewBox="0 0 24 24">
                <path d="M12 .5C5.7.5.6 5.6.6 11.9c0 5 3.3 9.3 7.9 10.8.6.1.8-.2.8-.6v-2c-3.2.7-3.9-1.4-3.9-1.4-.5-1.3-1.3-1.7-1.3-1.7-1-.7.1-.7.1-.7 1.1.1 1.8 1.2 1.8 1.2 1 1.7 2.7 1.2 3.3.9.1-.7.4-1.2.7-1.5-2.6-.3-5.3-1.3-5.3-5.7 0-1.3.5-2.3 1.2-3.1-.1-.3-.5-1.5.1-3 0 0 1-.3 3.2 1.2.9-.3 1.9-.4 2.9-.4s2 .1 2.9.4c2.2-1.5 3.2-1.2 3.2-1.2.6 1.5.2 2.7.1 3 .8.8 1.2 1.8 1.2 3.1 0 4.4-2.7 5.4-5.3 5.7.4.4.8 1.1.8 2.2v3.2c0 .3.2.7.8.6 4.6-1.5 7.9-5.8 7.9-10.8C23.4 5.6 18.3.5 12 .5z" />
              </svg>
              {messages.intro.continueWithGitHub}
            </button>
            <div className="setupDivider">
              <span />
              <p>{messages.intro.manualSetupDivider}</p>
              <span />
            </div>
          </div>

          <div className="setupList" id="setup">
            <SetupStep
              copied={copiedTarget === "install"}
              command={installCommand}
              index="1"
              label={messages.intro.installSpill}
              onCopy={onCopyInstall}
            />
            <SetupStep
              copied={copiedTarget === "setup"}
              command={setupPrompt}
              hideCommand
              index="2"
              label={messages.intro.tokenMeteringInstallPrompt}
              onCopy={onCopySetup}
            />
          </div>

          <p className="signinLine" id="about">
            {messages.intro.alreadyHaveAccount}{" "}
            <button type="button" onClick={onOpenDashboard}>
              {messages.intro.signIn}
            </button>
          </p>
        </section>
      </main>

      <footer className="introFooter">
        <strong>Spill</strong>
        <div>
          <p>{messages.intro.copyright}</p>
          <nav aria-label={messages.intro.footerLabel}>
            <a href="#setup">{messages.intro.terms}</a>
            <a href="#setup">{messages.nav.privacy}</a>
            <a href="#setup">{messages.intro.twitter}</a>
            <a href="#setup">{messages.intro.instagram}</a>
          </nav>
        </div>
      </footer>
    </>
  );
}
