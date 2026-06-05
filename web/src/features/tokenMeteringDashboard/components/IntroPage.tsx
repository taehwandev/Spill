import { formatTokens, type DashboardModel } from "../dashboardModel";
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
  return (
    <>
      <nav className="introNav" aria-label="Intro navigation">
        <div className="introBrand">Spill</div>
        <div className="introLinks">
          <a href="#features">Features</a>
          <a href="#setup">Setup</a>
          <a href="#about">About</a>
          <button className="downloadButton" type="button" onClick={onOpenDashboard}>
            Download
          </button>
        </div>
      </nav>

      <main className="introMain">
        <section className="previewColumn" aria-label="Dashboard preview">
          <div className="previewLabel">Cloud dashboard preview</div>
          <div>
            <h1>
              Intelligence,
              <span>Metered.</span>
            </h1>
          </div>

          <div className="previewStack" aria-hidden="true">
            <article className="previewCard large">
              <div className="previewHeader">
                <div>
                  <p>Current token usage</p>
                  <strong>{dashboard.kpis[0]?.value ?? "0"} tokens</strong>
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
                  <span>Token Metering</span>
                </div>
                <div className="snapshotNav">
                  <span>Overview</span>
                  <span>Hotspots</span>
                  <span>Sessions</span>
                  <span>Settings</span>
                </div>
                <div className="snapshotStatus">
                  <span />
                  Cloud preview data
                </div>
                <div className="snapshotCard">
                  <p>Sync mode status</p>
                  <strong>Cloud not connected</strong>
                  <em>Local detail stays in the macOS app until sync is enabled.</em>
                  <div className="snapshotPills">
                    <span />
                    <span />
                    <span />
                  </div>
                </div>
                <div className="snapshotKpis">
                  {dashboard.kpis.map((kpi) => (
                    <span key={kpi.label}>
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
                <p>Cost estimate</p>
                <div className="miniDashboard">
                  {dashboard.taskBreakdown.slice(0, 6).map((row) => (
                    <span key={row.id}>
                      <i style={{ width: `${Math.max(16, row.percentage)}%` }} />
                    </span>
                  ))}
                </div>
                <div className="miniMetricRow">
                  <strong>{dashboard.kpis[3]?.value ?? "$0.00"}</strong>
                  <em>-12% MoM</em>
                </div>
              </article>
              <article className="previewCard">
                <p>Task breakdown</p>
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
            <h2>Spill it all.</h2>
            <p>
              Join the ecosystem where AI usage metering fluidly integrates
              with your workflow. No content collection, just flow.
            </p>
          </div>

          <div className="authPanel" id="features">
            <button className="githubButton" type="button" onClick={onOpenDashboard}>
              <svg aria-hidden="true" viewBox="0 0 24 24">
                <path d="M12 .5C5.7.5.6 5.6.6 11.9c0 5 3.3 9.3 7.9 10.8.6.1.8-.2.8-.6v-2c-3.2.7-3.9-1.4-3.9-1.4-.5-1.3-1.3-1.7-1.3-1.7-1-.7.1-.7.1-.7 1.1.1 1.8 1.2 1.8 1.2 1 1.7 2.7 1.2 3.3.9.1-.7.4-1.2.7-1.5-2.6-.3-5.3-1.3-5.3-5.7 0-1.3.5-2.3 1.2-3.1-.1-.3-.5-1.5.1-3 0 0 1-.3 3.2 1.2.9-.3 1.9-.4 2.9-.4s2 .1 2.9.4c2.2-1.5 3.2-1.2 3.2-1.2.6 1.5.2 2.7.1 3 .8.8 1.2 1.8 1.2 3.1 0 4.4-2.7 5.4-5.3 5.7.4.4.8 1.1.8 2.2v3.2c0 .3.2.7.8.6 4.6-1.5 7.9-5.8 7.9-10.8C23.4 5.6 18.3.5 12 .5z" />
              </svg>
              Continue with GitHub
            </button>
            <div className="setupDivider">
              <span />
              <p>Or set up manually</p>
              <span />
            </div>
          </div>

          <div className="setupList" id="setup">
            <SetupStep
              copied={copiedTarget === "install"}
              command={installCommand}
              index="1"
              label="Install Spill"
              onCopy={onCopyInstall}
            />
            <SetupStep
              copied={copiedTarget === "setup"}
              command={setupPrompt}
              index="2"
              label="Global Agent Prompt"
              multiline
              onCopy={onCopySetup}
            />
          </div>

          <p className="signinLine" id="about">
            Already have an account?{" "}
            <button type="button" onClick={onOpenDashboard}>
              Sign In
            </button>
          </p>
        </section>
      </main>

      <footer className="introFooter">
        <strong>Spill</strong>
        <div>
          <p>© 2024 Spill. All rights reserved. Don't hold it back, Just Spill it.</p>
          <nav aria-label="Intro footer links">
            <a href="#setup">Terms</a>
            <a href="#setup">Privacy</a>
            <a href="#setup">Twitter</a>
            <a href="#setup">Instagram</a>
          </nav>
        </div>
      </footer>
    </>
  );
}
