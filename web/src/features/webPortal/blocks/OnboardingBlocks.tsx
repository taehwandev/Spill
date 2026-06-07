import type { DashboardModel } from "../../tokenMeteringDashboard/dashboardModel";
import { installCommand } from "../../tokenMeteringDashboard/setupCopy";
import { AuthControls } from "../components/AuthControls";
import { MaterialIcon } from "../components/MaterialIcon";
import type { SpillAuthProvider, SpillAuthState } from "../model/spillAuth";
import type { PortalRoute } from "../routes";

export function OnboardingHeroBlock({
  auth,
  copiedInstall,
  onCopyInstall,
  onNavigate,
  onSignIn,
  onSignOut
}: {
  auth: SpillAuthState;
  copiedInstall: boolean;
  onCopyInstall: () => void;
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  return (
    <section className="heroSection">
      <div className="heroBadge">
        <MaterialIcon filled name="verified" />
        <span>macOS Control Tray</span>
      </div>

      <h1>
        Don't hold it back,
        <span> Just Spill it.</span>
      </h1>
      <p>
        A compact macOS control tray and local usage dashboard for AI-heavy
        work.
      </p>

      <div className="heroActions">
        <button className="primaryAction" onClick={onCopyInstall} type="button">
          Download Mac App
        </button>
        <button className="secondaryAction" onClick={() => onNavigate("dashboard")} type="button">
          Open Dashboard
        </button>
        <AuthControls state={auth} onSignIn={onSignIn} onSignOut={onSignOut} />
      </div>

      <div className="terminalCard" aria-label="Spill install command">
        <div className="terminalTop">
          <span className="traffic red" />
          <span className="traffic yellow" />
          <span className="traffic green" />
          <strong>ZSH · INSTALL.SH</strong>
        </div>
        <div className="terminalBody">
          <code>
            <span>$</span> {installCommand}
          </code>
          <button
            aria-label="Copy install command"
            onClick={onCopyInstall}
            type="button"
          >
            <MaterialIcon name={copiedInstall ? "check" : "content_copy"} />
          </button>
        </div>
      </div>
      <small className="installNote">Requires macOS 12.0 or higher</small>
    </section>
  );
}

export function OnboardingFlowPreviewBlock({
  dashboard
}: {
  dashboard: DashboardModel;
}) {
  const kpis = dashboard.kpis;

  return (
    <section className="flowSection" id="features">
      <div className="sectionHeading">
        <span>Dashboard</span>
        <h2>Local usage at a glance.</h2>
      </div>

      <div className="dashboardPreview glassPanel">
        <aside className="previewRail" aria-hidden="true">
          <span className="active">
            <MaterialIcon filled name="dashboard" />
            Overview
          </span>
          <span>
            <MaterialIcon name="analytics" />
            Analytics
          </span>
          <span>
            <MaterialIcon name="settings" />
            Settings
          </span>
        </aside>

        <div className="previewCanvas">
          <div className="previewHeader">
            <div>
              <h3>Usage Overview</h3>
              <p>Local token totals and activity patterns</p>
            </div>
            <div className="previewPills">
              <span>Local</span>
              <span>Content stays private</span>
            </div>
          </div>

          <div className="previewMetricGrid">
            {kpis.slice(0, 3).map((kpi, index) => (
              <article className="previewMetric" key={kpi.id}>
                <span>{kpi.label}</span>
                <strong className={index === 1 ? "blue" : ""}>{kpi.value}</strong>
                <i style={{ width: `${Math.max(16, dashboard.aiToolBreakdown[index]?.percentage ?? 32)}%` }} />
              </article>
            ))}
          </div>

          <div className="streamChart" aria-hidden="true">
            <svg preserveAspectRatio="none" viewBox="0 0 1000 120">
              <path d="M0,120 L0,62 C110,44 190,78 302,65 C430,50 492,26 628,44 C744,60 825,46 1000,58 L1000,120 Z" />
            </svg>
            <span>Weekly activity pattern</span>
          </div>
        </div>
      </div>
    </section>
  );
}

export function OnboardingFeatureGridBlock() {
  return (
    <section className="featureGrid" id="security">
      <article className="featureCard wide">
        <div className="featureCopy">
          <span className="featureIcon">
            <MaterialIcon filled name="speed" />
          </span>
          <h3>Performance Hub</h3>
          <p>
            Deep-dive into local agent usage. Track token volume, latency,
            stage breakdowns, and model cost pressure from one dashboard.
          </p>
          <ul>
            <li><MaterialIcon filled name="check_circle" /> Per-tool activity tracking</li>
            <li><MaterialIcon filled name="check_circle" /> Content stays private</li>
          </ul>
        </div>
        <div className="barVisual" aria-hidden="true">
          <span />
          <span />
          <span />
          <span />
        </div>
      </article>

      <article className="featureCard">
        <span className="featureIcon blue">
          <MaterialIcon filled name="grid_view" />
        </span>
        <h3>Productivity Engine</h3>
        <p>
          Compare Codex, Claude, and Antigravity activity across work stages,
          sessions, and devices.
        </p>
        <div className="windowMosaic" aria-hidden="true">
          <span />
          <span />
          <span />
        </div>
      </article>

      <article className="featureCard">
        <span className="featureIcon slate">
          <MaterialIcon filled name="shield" />
        </span>
        <h3>Purely Local First</h3>
        <p>
          Usage stays local unless you choose to back it up.
        </p>
      </article>

      <article className="imageFeature">
        <img
          alt="Abstract data-flow lines representing secure token sync"
          src="https://lh3.googleusercontent.com/aida-public/AB6AXuAfg1s0k0RtsFNJUwTcNZxBRhIB2uvRLsANLwd1e1BwwFsppnOKg2u6f8JEAFZ5EeZkImt8dWL_5-ayPHfs4LHxET7-B37lhQixPKKbtimhEdcbJSDqie_z_RbBLV94rz0hMjHONXT6DaHzdRiQ2rlOYsFvkDa7lEhq6h0TiPIuvz6XHskKXp52AgmLiyJ66lABgRX3YjalEqlhxyWuCJ8zNqacf5rUGBEWq7J0yC6zB1EBlVlI5uSCLkSIqCW2aRXZ2zDPS9xdgP0"
        />
        <div>
          <h3>Architected for speed.</h3>
          <p>
            Lightweight local capture and clear privacy controls.
          </p>
        </div>
      </article>
    </section>
  );
}

export function OnboardingFinalCtaBlock({
  onNavigate
}: {
  onNavigate: (route: PortalRoute) => void;
}) {
  return (
    <section className="finalCta" id="docs">
      <h2>Ready to use Spill?</h2>
      <p>Install the Mac app, then review local usage from the dashboard.</p>
      <div>
        <button className="primaryAction" onClick={() => onNavigate("dashboard")} type="button">
          Open Dashboard
        </button>
        <button className="secondaryAction" type="button">
          Read Documentation
        </button>
      </div>
    </section>
  );
}
